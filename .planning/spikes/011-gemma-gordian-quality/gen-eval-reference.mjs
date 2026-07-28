#!/usr/bin/env node
// Spike 011 — generates Gemini's REFERENCE outputs for the sealed holdout.
// These are the eval comparison column, never training data.
//   GEMINI_DATASET_KEY=... node gen-eval-reference.mjs
// Writes out/eval-gemini.jsonl

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

const KEY = process.env.GEMINI_DATASET_KEY;
if (!KEY) { console.error("GEMINI_DATASET_KEY not set"); process.exit(1); }

const base = new URL("../009-distillation-dataset/", import.meta.url);
const corpus = readFileSync(new URL("corpus/dilemmas.jsonl", base), "utf8").trim().split("\n").map(JSON.parse);
const evalIds = new Set(readFileSync(new URL("corpus/eval-ids.txt", base), "utf8").trim().split("\n"));
const rows = corpus.filter((r) => evalIds.has(r.id) && (r.mode === "binary" || r.mode === "yesNo"));

const MODEL = "gemini-3.5-flash";
async function generate(system, user, schema) {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: { responseMimeType: "application/json", responseSchema: schema },
    }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  return JSON.parse((data.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? "").join(""));
}

const qSchema = { type: "OBJECT", properties: {
  optionA: { type: "STRING" }, optionB: { type: "STRING" },
  questions: { type: "ARRAY", items: { type: "STRING" }, minItems: 8, maxItems: 10 } },
  required: ["optionA", "optionB", "questions"] };
const vSchema = { type: "OBJECT", properties: {
  decision: { type: "STRING" }, sentiment: { type: "STRING", enum: ["DECIDED", "SPLIT"] },
  analysis: { type: "STRING" }, nextStep: { type: "STRING" } },
  required: ["decision", "sentiment", "analysis", "nextStep"] };

function qSystem(mode, a, b) {
  return "You write rapid-fire, high-intensity bypass questions (maximum 12 words each) designed to bypass the analytical brain and force an immediate gut response. CRITICAL: every question must be answerable INSTANTLY by tapping one of the two option buttons. "
    + (mode === "binary"
      ? `Frame questions like 'Which one would you start tonight?' so each is answered by picking '${a}' or '${b}'. Never yes/no phrasing, never 'how much' phrasing.`
      : "Use direct yes/no phrasing only.")
    + " Every question must name a concrete detail of the user's exact dilemma. Never give advice. Never mention AI.";
}
const V_SYS = "You state the decision a user's own rapid-fire answers point to. You are a mirror: every claim must come from the answers, quoted or plainly restated. The decision is ONE imperative sentence naming the choice - never a question. The next step is one concrete physical action doable within 24 hours - never 'decide', 'consider', or 'reflect'. Never mention AI.";

function answerPattern(id, questions, a, b) {
  let h = 0; for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return questions.map((q, i) => `Q: ${q}\nA: ${((h >> i % 24) & 1) ? b : a}${((h >> (i + 7) % 24) & 3) === 0 ? " (hesitated)" : ""}`).join("\n");
}

const out = [];
for (const row of rows) {
  try {
    const q = await generate(
      qSystem(row.mode, "the first option", "the second option"),
      `Dilemma: ${row.dilemma}` + (row.mode === "binary"
        ? "\nExtract the two alternatives as short Title Case button labels (optionA, optionB), then write the questions so each is answered by picking one label."
        : "\nSet optionA to 'No' and optionB to 'Yes'."),
      qSchema);
    const a = row.mode === "binary" ? q.optionA : "No";
    const b = row.mode === "binary" ? q.optionB : "Yes";
    const transcript = answerPattern(row.id, q.questions, a, b);
    const v = await generate(V_SYS, `Dilemma: ${row.dilemma}\n\nAnswers given under a 60-second clock:\n${transcript}\n\nState the verdict.`, vSchema);
    out.push({ id: row.id, dilemma: row.dilemma, mode: row.mode, questions: q, transcript, verdict: v });
    console.log(row.id, "ok");
    await new Promise((r) => setTimeout(r, 400));
  } catch (e) { console.error(row.id, "FAILED", e.message); }
}
mkdirSync(new URL("./out/", import.meta.url), { recursive: true });
writeFileSync(new URL("./out/eval-gemini.jsonl", import.meta.url), out.map((r) => JSON.stringify(r)).join("\n") + "\n");
console.log(`eval-gemini.jsonl: ${out.length} reference rows`);
