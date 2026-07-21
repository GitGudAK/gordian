#!/usr/bin/env node
// Model bake-off: runs the same 20 dilemmas through every candidate model and
// prints (+ writes) a latency/mechanical-quality table. Imports the PRODUCTION
// adapters and prompt builders — no reimplemented wire logic. Node ≥22 runs
// .mts directly via native type stripping.
//
//   node scripts/bake-off.mts [--limit N] [--models gemini:gemini-3.5-flash,anthropic:claude-haiku-4-5]
//
// Keys come from process.env (GEMINI_API_KEY / ANTHROPIC_API_KEY); providers
// without a key are skipped loudly; no keys at all → skip message, exit 0.

import { mkdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import * as gemini from "../src/providers/gemini.ts";
import * as anthropic from "../src/providers/anthropic.ts";
import { parseModelVar, type OperationConfig, type ProviderEnv, type StructuredRequest } from "../src/providers/types.ts";
import * as ops from "../src/operations.ts";

interface Dilemma {
  scenario: string;
  style: "BINARY" | "YES_NO";
}

// 20 dilemmas: 10 BINARY-style, 10 YES_NO-style, including the four app demo scenarios.
const DILEMMAS: Dilemma[] = [
  { scenario: "Should I learn Spanish or German?", style: "BINARY" }, // app demo
  { scenario: "Should I move to Berlin or stay in Austin?", style: "BINARY" }, // app demo
  { scenario: "Should I stay in the US or move back home to be closer to family?", style: "BINARY" }, // app demo
  { scenario: "Should I take the promotion or switch to the smaller company?", style: "BINARY" },
  { scenario: "Should I rent downtown or buy in the suburbs?", style: "BINARY" },
  { scenario: "Should I study medicine or computer science?", style: "BINARY" },
  { scenario: "Should I adopt a dog or a cat?", style: "BINARY" },
  { scenario: "Should I spend the bonus on travel or savings?", style: "BINARY" },
  { scenario: "Should I go back to school or keep working?", style: "BINARY" },
  { scenario: "Should I tell him now or wait until after the wedding?", style: "BINARY" },
  { scenario: "Should I take the startup offer?", style: "YES_NO" }, // app demo
  { scenario: "Should I quit my job to freelance?", style: "YES_NO" },
  { scenario: "Should I end this five-year relationship?", style: "YES_NO" },
  { scenario: "Should I sign up for the marathon?", style: "YES_NO" },
  { scenario: "Should I confront my roommate about the mess?", style: "YES_NO" },
  { scenario: "Should I start the side business this year?", style: "YES_NO" },
  { scenario: "Should I ask for a raise this quarter?", style: "YES_NO" },
  { scenario: "Should I move out of my parents' house now?", style: "YES_NO" },
  { scenario: "Should I sell the car and bike to work?", style: "YES_NO" },
  { scenario: "Should I finally publish the novel draft?", style: "YES_NO" },
];

// Canned rapid-fire answers (startDemoVerdict shape: question/choice/reflection, some empty).
const CANNED_ANSWERS: ops.Answer[] = [
  { question: "Are you choosing out of ambition or fear?", choice: "YES", reflection: "mostly fear of missing family moments" },
  { question: "Would your 80-year-old self regret choosing stagnation?", choice: "YES", reflection: "" },
  { question: "Is comfort more important to you than growth?", choice: "NO", reflection: "" },
  { question: "If no one was looking, what would your answer be?", choice: "YES", reflection: "" },
  { question: "Will you be thinking about this same problem next year?", choice: "YES", reflection: "" },
];

const SESSION_PLAN_MODELS = ["gemini:gemini-3.5-flash", "anthropic:claude-haiku-4-5"];
const VERDICT_MODELS = ["gemini:gemini-3.5-flash", "anthropic:claude-haiku-4-5", "anthropic:claude-sonnet-5"];

const env: ProviderEnv = {
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
};

if (!env.GEMINI_API_KEY && !env.ANTHROPIC_API_KEY) {
  console.log("SKIPPED: no provider keys in env. Set GEMINI_API_KEY and/or ANTHROPIC_API_KEY to run the bake-off.");
  process.exit(0);
}

const args = process.argv.slice(2);
function argValue(flag: string): string | undefined {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
}
const limit = parseInt(argValue("--limit") ?? "", 10) || DILEMMAS.length;
const modelsOverride = argValue("--models")?.split(",").map((m) => m.trim());
const dilemmas = DILEMMAS.slice(0, limit);

function hasKey(config: OperationConfig): boolean {
  return config.provider === "gemini" ? Boolean(env.GEMINI_API_KEY) : Boolean(env.ANTHROPIC_API_KEY);
}

function adapterFor(config: OperationConfig) {
  return config.provider === "gemini" ? gemini.generateStructured : anthropic.generateStructured;
}

function wordCount(s: string): number {
  return s.trim().split(/\s+/).filter(Boolean).length;
}

interface Row {
  dilemma: number;
  op: string;
  model: string;
  latencyMs: number;
  validJson: boolean;
  detail: string;
}

const rows: Row[] = [];
const skipped = new Set<string>();

function resolveModels(defaults: string[]): OperationConfig[] {
  return (modelsOverride ?? defaults).map(parseModelVar).filter((c) => {
    if (!hasKey(c)) {
      skipped.add(`${c.provider} (no ${c.provider === "gemini" ? "GEMINI_API_KEY" : "ANTHROPIC_API_KEY"})`);
      return false;
    }
    return true;
  });
}

async function runOne(op: "session-plan" | "verdict", config: OperationConfig, d: Dilemma, index: number): Promise<void> {
  const req: StructuredRequest =
    op === "session-plan"
      ? {
          system: ops.sessionPlanSystem(d.scenario),
          user: ops.SESSION_PLAN_USER,
          geminiSchema: ops.SESSION_PLAN_GEMINI_SCHEMA,
          anthropicSchema: ops.SESSION_PLAN_ANTHROPIC_SCHEMA,
          temperature: ops.TEMPERATURE,
        }
      : {
          system: ops.verdictSystem(d.scenario, CANNED_ANSWERS),
          user: ops.VERDICT_USER,
          geminiSchema: ops.VERDICT_GEMINI_SCHEMA,
          anthropicSchema: ops.VERDICT_ANTHROPIC_SCHEMA,
          temperature: ops.TEMPERATURE,
        };

  const started = Date.now();
  try {
    const text = await adapterFor(config)(req, config.model, env);
    const latencyMs = Date.now() - started;
    const payload = JSON.parse(text) as Record<string, unknown>;
    if (op === "session-plan") {
      const questions = Array.isArray(payload.questions) ? (payload.questions as string[]) : [];
      const valid =
        typeof payload.mode === "string" &&
        typeof payload.optionA === "string" &&
        typeof payload.optionB === "string" &&
        questions.length > 0;
      const maxWords = questions.reduce((m, q) => Math.max(m, wordCount(q)), 0);
      rows.push({
        dilemma: index + 1,
        op,
        model: `${config.provider}:${config.model}`,
        latencyMs,
        validJson: valid,
        detail: `mode=${payload.mode} (expected ${d.style}) · ${questions.length} questions · max ${maxWords} words`,
      });
    } else {
      const decision = typeof payload.decision === "string" ? payload.decision : "";
      const valid = ["decision", "sentiment", "analysis", "probe"].every(
        (f) => typeof payload[f] === "string" && (payload[f] as string).length > 0,
      );
      const dw = wordCount(decision);
      rows.push({
        dilemma: index + 1,
        op,
        model: `${config.provider}:${config.model}`,
        latencyMs,
        validJson: valid,
        detail: `"${decision.slice(0, 60)}" · ${dw} words${dw <= 15 ? "" : " (OVER 15)"}`,
      });
    }
  } catch (err) {
    rows.push({
      dilemma: index + 1,
      op,
      model: `${config.provider}:${config.model}`,
      latencyMs: Date.now() - started,
      validJson: false,
      detail: `ERROR: ${err instanceof Error ? err.message.slice(0, 80) : String(err)}`,
    });
  }
}

const sessionModels = resolveModels(SESSION_PLAN_MODELS);
const verdictModels = resolveModels(VERDICT_MODELS);

for (const [i, d] of dilemmas.entries()) {
  for (const config of sessionModels) await runOne("session-plan", config, d, i);
  for (const config of verdictModels) await runOne("verdict", config, d, i);
  process.stderr.write(`\rdilemma ${i + 1}/${dilemmas.length}`);
}
process.stderr.write("\n");

for (const s of skipped) console.log(`SKIPPED provider: ${s}`);

// Markdown table
const lines: string[] = [];
lines.push(`# Bake-off — ${new Date().toISOString()}`);
lines.push("");
lines.push(`Dilemmas: ${dilemmas.length} · session-plan models: ${sessionModels.length} · verdict models: ${verdictModels.length}`);
lines.push("");
lines.push("| # | op | model | latency_ms | valid_json | detail |");
lines.push("|---|----|-------|-----------:|:----------:|--------|");
for (const r of rows) {
  lines.push(`| ${r.dilemma} | ${r.op} | ${r.model} | ${r.latencyMs} | ${r.validJson ? "yes" : "NO"} | ${r.detail} |`);
}
lines.push("");
lines.push("## Per-model summary");
lines.push("");
lines.push("| model | op | calls | parse ok | median latency_ms |");
lines.push("|-------|----|------:|---------:|------------------:|");
const groups = new Map<string, Row[]>();
for (const r of rows) {
  const key = `${r.model}|${r.op}`;
  groups.set(key, [...(groups.get(key) ?? []), r]);
}
for (const [key, group] of groups) {
  const [model, op] = key.split("|");
  const okCount = group.filter((r) => r.validJson).length;
  const latencies = group.map((r) => r.latencyMs).sort((a, b) => a - b);
  const median = latencies[Math.floor(latencies.length / 2)];
  lines.push(`| ${model} | ${op} | ${group.length} | ${okCount}/${group.length} | ${median} |`);
}
const report = lines.join("\n");
console.log(`\n${report}`);

const outDir = join(dirname(fileURLToPath(import.meta.url)), "bake-off-results");
mkdirSync(outDir, { recursive: true });
const outPath = join(outDir, `${new Date().toISOString().replace(/[:.]/g, "-")}.md`);
writeFileSync(outPath, report);
console.log(`\nwritten: ${outPath}`);
