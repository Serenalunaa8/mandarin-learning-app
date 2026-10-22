const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const providers = {
  gemini: {
    label: "Gemini",
    model: "gemini-2.5-flash",
    secret: "GEMINI_API_KEY",
  },
  openai: {
    label: "OpenAI",
    model: "gpt-6-luna",
    secret: "OPENAI_API_KEY",
  },
  anthropic: {
    label: "Anthropic",
    model: "claude-haiku-5-5",
    secret: "ANTHROPIC_API_KEY",
  },
  groq: {
    label: "Groq",
    model: "llama-3.3-70b-versatile",
    secret: "GROQ_API_KEY",
  },
} as const;

const systemPrompt =
  "Kamu adalah tutor bahasa Mandarin untuk pemula berbahasa Indonesia. " +
  "Jawab jelas dan ringkas, sertakan Hanzi, pinyin bertanda nada, dan terjemahan Indonesia jika relevan. " +
  "Jangan mengarang data atau menyatakan jawaban pasti jika tidak yakin.";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
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
        `https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent?key=${apiKey}`;
      headers = { "Content-Type": "application/json" };
      requestBody = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: 1200, temperature: 0.4 },
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
    case "groq":
      endpoint = providerId === "openai"
        ? "https://api.openai.com/v1/chat/completions"
        : "https://api.groq.com/openai/v1/chat/completions";
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
        ...(providerId === "openai"
          ? { max_completion_tokens: 1200, reasoning_effort: "none" }
          : { max_tokens: 1200, temperature: 0.4 }),
      };
      break;
    default:
      return jsonResponse({ error: "Provider AI tidak didukung." }, 400);
  }

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody),
      signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) {
      console.error(`${providerId} returned HTTP ${response.status}`);
      return jsonResponse(
        { error: `${provider.label} menolak permintaan (HTTP ${response.status}).` },
        502,
      );
    }

    const result = await response.json();
    let answer: string | undefined;
    if (providerId === "gemini") {
      answer = result.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part.text ?? "")
        .join("");
    } else if (providerId === "anthropic") {
      answer = result.content
        ?.map((part: { text?: string }) => part.text ?? "")
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
    console.error(`${providerId} request failed`, error);
    return jsonResponse({ error: "Layanan AI gagal dihubungi." }, 502);
  }
});
