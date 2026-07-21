// Secrets are set with `wrangler secret put` and never appear in wrangler.jsonc,
// so `wrangler types` cannot emit them — merged into the generated global Env here.
interface Env {
  GEMINI_API_KEY?: string;
  ANTHROPIC_API_KEY?: string;
}
