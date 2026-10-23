const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const providers = {
  gemini: {
    label: "Gemini",
    model: "gemini-3.5-flash-lite",
    secret: "GEMINI_API_KEY",
    style: "Susun penjelasan dengan rapi dan gunakan perbandingan atau konteks budaya bila benar-benar relevan.",
  },
  openai: {
    label: "OpenAI",
    model: "gpt-6-luna",
    secret: "OPENAI_API_KEY",
    style: "Gunakan gaya percakapan yang hangat. Beri dialog latihan singkat bila sesuai dengan pertanyaan.",
  },
  anthropic: {
    label: "Anthropic",
    model: "claude-haiku-5-5",
    secret: "ANTHROPIC_API_KEY",
    style: "Jelaskan alasan tata bahasa dan nuansa pemakaian secara teliti, lalu bedakan dari kesalahan umum.",
  },
  groq: {
    label: "Groq GPT-OSS",
    model: "openai/gpt-oss-120b",
    secret: "GROQ_API_KEY",
    style: "Jawab dengan ringkas, langsung ke inti, dan tutup dengan rumus atau contoh singkat yang mudah diingat.",
  },
} as const;

const baseSystemPrompt =
  "Kamu adalah tutor bahasa Mandarin untuk pemula berbahasa Indonesia. " +
  "Jawab pertanyaan yang benar-benar diajukan dalam bahasa Indonesia. " +
  "Untuk setiap contoh Mandarin, sertakan Hanzi, pinyin bertanda nada, dan arti Indonesia. " +
  "Utamakan aturan tata bahasa dan kosakata Mandarin yang baku; jangan mengarang fakta, " +
  "dan nyatakan dengan jujur jika ada lebih dari satu pemakaian atau jika tidak yakin.";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let body: { action?: string; provider?: string; prompt?: string };
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Request JSON tidak valid." }, 400);
  }

  if (body.action === "providers") {
    const availableProviders = Object.entries(providers)
      .filter(([, config]) => Boolean(Deno.env.get(config.secret)))
      .map(([id]) => id);
    return jsonResponse({ providers: availableProviders });
  }

  const providerId = body.provider as keyof typeof providers | undefined;
  const prompt = body.prompt?.trim();
  if (!providerId || !(providerId in providers)) {
    return jsonResponse({ error: "Provider AI tidak didukung." }, 400);
  }
  if (!prompt || prompt.length > 4000) {
    return jsonResponse(
      { error: "Pertanyaan wajib diisi dan maksimal 4.000 karakter." },
      400,
    );
  }

  const clientIp = request.headers.get("cf-connecting-ip");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!clientIp || !serviceRoleKey || !supabaseUrl) {
    console.error("AI quota limiter is missing trusted client or Supabase configuration");
    return jsonResponse(
      { error: "Pembatasan penggunaan AI belum siap. Coba lagi nanti." },
      503,
    );
  }
  const ipDigest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(clientIp),
  );
  const clientKey = Array.from(new Uint8Array(ipDigest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  try {
    const quotaResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/consume_ai_tutor_quota`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_client_key: clientKey,
          p_window_seconds: 3600,
          p_max_requests: 20,
        }),
      },
    );
    if (!quotaResponse.ok) {
      console.error(`AI quota check returned HTTP ${quotaResponse.status}`);
      return jsonResponse(
        { error: "Pembatasan penggunaan AI gagal diperiksa." },
        503,
      );
    }
    if (await quotaResponse.json() !== true) {
      return jsonResponse(
        { error: "Batas 20 pertanyaan per jam telah tercapai. Coba lagi nanti." },
        429,
      );
    }
  } catch (error) {
    console.error("AI quota check failed", error);
    return jsonResponse(
      { error: "Pembatasan penggunaan AI gagal diperiksa." },
      503,
    );
  }

  const provider = providers[providerId];
  const systemPrompt = `${baseSystemPrompt} ${provider.style}`;
  const apiKey = Deno.env.get(provider.secret);
  if (!apiKey) {
    return jsonResponse(
      { error: `Secret ${provider.secret} belum dikonfigurasi di Supabase.` },
      503,
    );
  }

  let endpoint: string;
  let headers: Record<string, string>;
  let requestBody: Record<string, unknown>;
  switch (providerId) {
    case "gemini":
      endpoint =
        `https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent`;
      headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      };
      requestBody = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: 1200 },
      };
      break;
    case "anthropic":
      endpoint = "https://api.anthropic.com/v1/messages";
      headers = {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      };
      requestBody = {
        model: provider.model,
        max_tokens: 1200,
        system: systemPrompt,
        messages: [{ role: "user", content: prompt }],
      };
      break;
    case "openai":
      endpoint = "https://api.openai.com/v1/responses";
      headers = {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      };
      requestBody = {
        model: provider.model,
        instructions: systemPrompt,
        input: prompt,
        max_output_tokens: 1200,
      };
      break;
    case "groq":
      endpoint = "https://api.groq.com/openai/v1/chat/completions";
      headers = {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      };
      requestBody = {
        model: provider.model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: prompt },
        ],
        max_tokens: 1200,
        temperature: 0.7,
      };
      break;
    default:
      return jsonResponse({ error: "Provider AI tidak didukung." }, 400);
  }

  try {
    const fetchProvider = () => fetch(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody),
      signal: AbortSignal.timeout(45000),
    });
    let response = await fetchProvider();
    if (providerId === "gemini" && response.status === 503) {
      await new Promise((resolve) => setTimeout(resolve, 800));
      response = await fetchProvider();
    }
    const responseText = await response.text();
    if (!response.ok) {
      let providerMessage = responseText;
      try {
        const errorBody = JSON.parse(responseText);
        providerMessage = errorBody.error?.message ?? responseText;
      } catch {
        // Keep the original response text when the provider doesn't return JSON.
      }
      const safeProviderMessage = providerMessage.slice(0, 500);
      console.error(
        `${providerId} returned HTTP ${response.status}: ${safeProviderMessage}`,
      );
      return jsonResponse(
        {
          error:
            `${provider.label} menolak permintaan (HTTP ${response.status}): ` +
            safeProviderMessage,
        },
        502,
      );
    }

    const result = JSON.parse(responseText);
    let answer: string | undefined;
    if (providerId === "gemini") {
      answer = result.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part.text ?? "")
        .join("");
    } else if (providerId === "anthropic") {
      answer = result.content
        ?.map((part: { text?: string }) => part.text ?? "")
        .join("");
    } else if (providerId === "openai") {
      answer = result.output
        ?.filter((item: { type?: string }) => item.type === "message")
        .flatMap((item: { content?: { type?: string; text?: string }[] }) =>
          item.content ?? []
        )
        .filter((part: { type?: string }) => part.type === "output_text")
        .map((part: { text?: string }) => part.text ?? "")
        .join("");
    } else {
      answer = result.choices?.[0]?.message?.content;
    }

    if (typeof answer !== "string" || !answer.trim()) {
      console.error(`${providerId} response did not contain answer text`);
      return jsonResponse({ error: "Model AI tidak menghasilkan jawaban." }, 502);
    }
    return jsonResponse({ answer: answer.trim(), provider: providerId });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`${providerId} request failed: ${errorMessage}`);
    return jsonResponse(
      { error: `Layanan ${provider.label} gagal dihubungi: ${errorMessage}` },
      502,
    );
  }
});
