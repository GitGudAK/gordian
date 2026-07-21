// Shared provider/router contracts.
// CONSTRAINT: this module (and everything providers/*.ts + operations.ts import)
// must stay importable from plain Node — no workerd-specific imports — so
// scripts/bake-off.mts can exercise the production adapters directly.

// "weekly_meter_exhausted" is RESERVED for the Phase 3.5 freemium meter:
// defined in the union so the app can map it today, never returned this phase.
export type ErrorCode =
  | "bad_request"
  | "rate_limited"
  | "weekly_meter_exhausted"
  | "spend_cap"
  | "upstream_error"
  | "not_found";

export const ERROR_STATUS: Record<ErrorCode, number> = {
  bad_request: 400,
  rate_limited: 429,
  weekly_meter_exhausted: 429,
  spend_cap: 429,
  upstream_error: 502,
  not_found: 404,
};

/** Thrown by provider adapters; the router maps it to error code "upstream_error". */
export class UpstreamError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UpstreamError";
  }
}

export interface StructuredRequest {
  system: string;
  user: string;
  /** Gemini responseSchema dialect (uppercase OpenAPI-style types). */
  geminiSchema: unknown;
  /** Anthropic output_config dialect (lowercase JSON Schema, additionalProperties:false). */
  anthropicSchema: unknown;
  temperature: number;
  maxTokens?: number;
}

/** The subset of worker env the adapters need — plain strings so Node can supply process.env. */
export interface ProviderEnv {
  GEMINI_API_KEY?: string;
  ANTHROPIC_API_KEY?: string;
}

export type ProviderName = "gemini" | "anthropic";

export interface Provider {
  name: ProviderName;
  /** Resolves to the model's JSON text (repaired/validated by the adapter). */
  generateStructured(req: StructuredRequest, model: string, env: ProviderEnv): Promise<string>;
}

export interface OperationConfig {
  provider: ProviderName;
  model: string;
}

/** Parses a "{provider}:{model}" worker var (split on the FIRST ":"). */
export function parseModelVar(v: string): OperationConfig {
  const idx = v.indexOf(":");
  if (idx < 1 || idx === v.length - 1) {
    throw new Error(`invalid model var (expected "provider:model"): ${v}`);
  }
  const provider = v.slice(0, idx);
  const model = v.slice(idx + 1);
  if (provider !== "gemini" && provider !== "anthropic") {
    throw new Error(`unknown provider in model var: ${provider}`);
  }
  return { provider, model };
}
