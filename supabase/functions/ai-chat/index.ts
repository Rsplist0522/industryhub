import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonResponse = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Only POST is supported." }, 405);

  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey) return jsonResponse({ error: "AI service is not configured on the server." }, 503);

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse({ error: "Request body must be valid JSON." }, 400);
  }

  const systemPrompt = typeof payload.system_prompt === "string" ? payload.system_prompt.trim().slice(0, 12000) : "";
  const userInput = typeof payload.user_input === "string" ? payload.user_input.trim().slice(0, 20000) : "";
  if (!systemPrompt || !userInput) return jsonResponse({ error: "system_prompt and user_input are required." }, 400);

  const baseUrl = (Deno.env.get("AI_BASE_URL") ?? "https://api.groq.com/openai/v1").replace(/\/$/, "");
  const model = Deno.env.get("AI_MODEL") ?? "openai/gpt-oss-20b";

  try {
    const upstream = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.35,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: `${systemPrompt} Return JSON only. Do not use markdown fences or a preamble.` },
          { role: "user", content: userInput },
        ],
      }),
    });

    const raw = await upstream.text();
    if (!upstream.ok) {
      let providerMessage = raw.replace(/\s+/g, ' ').trim().slice(0, 500);
      try {
        const providerJson = JSON.parse(raw) as { error?: { message?: unknown } | string };
        const errorValue = providerJson.error;
        providerMessage = typeof errorValue === 'string'
          ? errorValue
          : errorValue && typeof errorValue === 'object' && 'message' in errorValue
            ? String(errorValue.message)
            : providerMessage;
      } catch (_) {
        // Keep the bounded plain-text response when the provider is not JSON.
      }
      console.error('AI provider rejected the request', {
        status: upstream.status,
        baseUrl,
        model,
        providerMessage,
      });
      return jsonResponse({
        error: `AI provider returned HTTP ${upstream.status}.`,
        provider_message: providerMessage || 'The provider did not return an error message.',
        provider_base_url: baseUrl,
        provider_model: model,
      }, 502);
    }

    const decoded = JSON.parse(raw) as { choices?: Array<{ message?: { content?: unknown } }> };
    const content = decoded.choices?.[0]?.message?.content;
    const text = typeof content === "string"
      ? content.replaceAll("```json", "").replaceAll("```", "").trim()
      : Array.isArray(content)
        ? content.map((part) => typeof part === "object" && part !== null && "text" in part ? String(part.text) : "").join("").trim()
        : "";
    if (!text) return jsonResponse({ error: "AI provider returned empty content." }, 502);

    const result = JSON.parse(text);
    if (typeof result !== "object" || result === null || Array.isArray(result)) return jsonResponse({ error: "AI provider returned an invalid JSON object." }, 502);
    return jsonResponse({ ...(result as Record<string, unknown>), __source: "ai" });
  } catch (error) {
    console.error("AI proxy error", error);
    return jsonResponse({ error: "AI request could not be completed." }, 502);
  }
});
