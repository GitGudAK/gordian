#!/usr/bin/env node
// Env-gated live smoke for the Gordian proxy. Plain Node, zero deps.
// Offline runs (CI, test suites) skip cleanly with exit 0.
//
//   GORDIAN_LIVE=1 node scripts/live-check.mjs                       # against wrangler dev
//   GORDIAN_LIVE=1 BASE_URL=https://... node scripts/live-check.mjs  # against a deployment

import { randomUUID } from "node:crypto";

if (process.env.GORDIAN_LIVE !== "1") {
  console.log("SKIPPED: set GORDIAN_LIVE=1 (and optionally BASE_URL) to run the live smoke");
  process.exit(0);
}

const BASE_URL = process.env.BASE_URL ?? "http://127.0.0.1:8787";
const deviceId = randomUUID();
const scenario = "Should I learn Spanish or German?";

function fail(label, detail) {
  console.error(`FAIL ${label}:`, detail);
  process.exit(1);
}

async function call(path, body) {
  const started = Date.now();
  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "X-Device-ID": deviceId },
    body: JSON.stringify(body),
  });
  const latency = Date.now() - started;
  const json = await res.json().catch(() => null);
  return { res, json, latency };
}

// 1. session-plan
{
  const { res, json, latency } = await call("/v1/session-plan", { scenario });
  if (!res.ok) {
    if (res.status === 502 && JSON.stringify(json).includes("not found")) {
      console.error("HINT: the Gemini model name may have 404'd — flip MODEL_SESSION_PLAN/MODEL_VERDICT to gemini:gemini-flash-latest in wrangler.jsonc and redeploy.");
    }
    fail("session-plan", json ?? res.status);
  }
  if (!json.mode || !json.optionA || !json.optionB) fail("session-plan", "missing mode/optionA/optionB");
  // Never trust "exactly 12" from a generative model (spike guidance).
  if (!Array.isArray(json.questions) || json.questions.length < 5 || json.questions.length > 15) {
    fail("session-plan", `questions count out of range: ${json.questions?.length}`);
  }
  console.log(`ok session-plan ${latency}ms mode=${json.mode} options=${json.optionA}/${json.optionB} questions=${json.questions.length} weekly=${res.headers.get("X-Weekly-Sessions")}`);
}

// 2. verdict
{
  const answers = [
    { question: "Which one would you start tonight?", choice: "SPANISH", reflection: "" },
    { question: "Which fits the life you want in five years?", choice: "SPANISH", reflection: "travel" },
    { question: "Which would you regret never trying?", choice: "GERMAN", reflection: "" },
  ];
  const { res, json, latency } = await call("/v1/verdict", { scenario, answers });
  if (!res.ok) fail("verdict", json ?? res.status);
  for (const field of ["decision", "sentiment", "analysis", "probe"]) {
    if (typeof json[field] !== "string" || json[field].length === 0) fail("verdict", `empty field: ${field}`);
  }
  console.log(`ok verdict ${latency}ms decision="${json.decision}" sentiment=${json.sentiment}`);
}

console.log("live smoke passed");
