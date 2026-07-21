import { defineConfig } from "vitest/config";
import { cloudflareTest } from "@cloudflare/vitest-pool-workers";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      // Secrets never live in wrangler.jsonc; tests get a dummy key and mock upstream.
      miniflare: { bindings: { GEMINI_API_KEY: "test-key" } },
    }),
  ],
  test: {},
});
