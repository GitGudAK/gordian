// Gemini generateContent adapter — server-side home of the spike-002 hardening:
//  - responseSchema on every call (plain JSON mode truncates ~40% on thinking models)
//  - ALL response parts concatenated (never parts[0] alone)
//  - bracket-repair ladder ported line-for-line from ios/Gordian/GeminiClient.swift
//  - key travels in the x-goog-api-key header, never a query param

import { UpstreamError, type ProviderEnv, type StructuredRequest } from "./types.ts";

interface GeminiPart {
  text?: string;
}

interface GenerateContentResponse {
  candidates?: Array<{
    content?: { parts?: GeminiPart[] };
    finishReason?: string;
  }>;
}

interface GeminiErrorEnvelope {
  error?: { code?: number; message?: string; status?: string };
}

/** Port of GeminiClient.cleanJSONText (itself a port of Android's cleanJson). */
export function cleanJSONText(raw: string): string {
  let s = raw.trim();
  if (s.startsWith("```json")) s = s.slice(7);
  if (s.startsWith("```")) s = s.slice(3);
  if (s.endsWith("```")) s = s.slice(0, -3);
  return s.trim();
}

/** Concatenate ALL parts of the first candidate — thinking models split output across parts. */
export function extractText(body: GenerateContentResponse): string {
  const parts = body.candidates?.[0]?.content?.parts ?? [];
  return parts.map((p) => p.text ?? "").join("");
}

/**
 * Fence-strip + parse, with the bracket-repair fallback for the thinking model's
 * occasional dropped closing "]" / "}" (finishReason STOP, ~40% in plain JSON mode).
 */
export function repairAndParse(text: string): unknown {
  const clean = cleanJSONText(text);
  try {
    return JSON.parse(clean);
  } catch {
    // fall through to repair
  }
  let repaired = clean;
  if (repaired.endsWith(",")) repaired = repaired.slice(0, -1);
  if (repaired.startsWith("[") && !repaired.endsWith("]")) repaired += "]";
  if (repaired.startsWith("{") && !repaired.endsWith("}")) repaired += "}";
  try {
    return JSON.parse(repaired);
  } catch {
    throw new UpstreamError("model output was not parseable JSON after repair");
  }
}

export async function generateStructured(
  req: StructuredRequest,
  model: string,
  env: ProviderEnv,
): Promise<string> {
  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey) throw new UpstreamError("GEMINI_API_KEY is not configured");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: req.system }] },
        contents: [{ parts: [{ text: req.user }] }],
        // No maxOutputTokens: the thinking model burns ~2000 thought tokens first.
        generationConfig: {
          temperature: req.temperature,
          responseMimeType: "application/json",
          responseSchema: req.geminiSchema,
        },
      }),
    },
  );

  if (!res.ok) {
    let message = `Gemini HTTP ${res.status}`;
    try {
      const envelope = (await res.json()) as GeminiErrorEnvelope;
      if (envelope.error?.message) message = envelope.error.message;
    } catch {
      // keep the status-only message; never surface the raw body
    }
    throw new UpstreamError(message);
  }

  const body = (await res.json()) as GenerateContentResponse;
  const text = extractText(body);
  if (!text) throw new UpstreamError("empty Gemini response");
  return JSON.stringify(repairAndParse(text));
}
