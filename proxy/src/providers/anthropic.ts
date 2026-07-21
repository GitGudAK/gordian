// Anthropic Messages API adapter — bake-off path (and hybrid-verdict candidate).
// output_config.format json_schema gives constrained decoding: the payload is
// schema-valid by construction, so this path needs no repair ladder.

import { UpstreamError, type ProviderEnv, type StructuredRequest } from "./types.ts";

interface MessagesResponse {
  content?: Array<{ type?: string; text?: string }>;
}

interface AnthropicErrorEnvelope {
  error?: { type?: string; message?: string };
}

export async function generateStructured(
  req: StructuredRequest,
  model: string,
  env: ProviderEnv,
): Promise<string> {
  const apiKey = env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new UpstreamError("ANTHROPIC_API_KEY is not configured");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      // REQUIRED by the Messages API — omitting max_tokens is a 400.
      max_tokens: req.maxTokens ?? 1024,
      system: req.system,
      messages: [{ role: "user", content: req.user }],
      output_config: {
        format: { type: "json_schema", schema: req.anthropicSchema },
      },
    }),
  });

  if (!res.ok) {
    let message = `Anthropic HTTP ${res.status}`;
    try {
      const envelope = (await res.json()) as AnthropicErrorEnvelope;
      if (envelope.error?.message) message = envelope.error.message;
    } catch {
      // keep the status-only message; never surface the raw body
    }
    throw new UpstreamError(message);
  }

  const body = (await res.json()) as MessagesResponse;
  const text = body.content?.[0]?.text;
  if (!text) throw new UpstreamError("empty Anthropic response");
  return text;
}
