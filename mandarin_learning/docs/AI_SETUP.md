# AI Tutor setup

The mobile and web clients call the `ai-tutor` Supabase Edge Function. Provider
API keys are kept in Supabase secrets and are never included in the app.

Apply the quota migration and deploy the function. Configure keys only for the
providers you want to offer:

```powershell
supabase link --project-ref <project-ref>
supabase db push
supabase secrets set GEMINI_API_KEY=your-key OPENAI_API_KEY=your-key ANTHROPIC_API_KEY=your-key GROQ_API_KEY=your-key
supabase functions deploy ai-tutor
```

Each provider is optional. The provider picker only lists providers whose
server-side secrets are configured: Gemini (`gemini-2.5-flash`), OpenAI GPT
(`gpt-6-luna`), Anthropic Claude (`claude-haiku-5-5`), and Groq
(`llama-3.3-70b-versatile`). Configure at least one secret and deploy the
function before asking questions. Requests are limited to 20 per IP per hour.
Provider usage may incur charges under the corresponding provider account.
