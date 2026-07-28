#!/usr/bin/env node
// Spike 011 — builds the Gemma LoRA training set from the 009 assets.
//   node build-training-set.mjs
// Reads  ../009-distillation-dataset/{corpus/dilemmas.jsonl, corpus/eval-ids.txt,
//        out/teacher-gemini.jsonl, out/teacher-claude.jsonl}
// Writes out/train.jsonl (chat-messages format) + out/eval-dilemmas.jsonl
//
// The judge rubric's MECHANICAL laws run here as hard filters; the semantic
// laws (grounding) were enforced by the teacher prompts and spot-checked.
// Eval-holdout rows never enter train.jsonl.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";

const base = new URL("../009-distillation-dataset/", import.meta.url);
const corpus = readFileSync(new URL("corpus/dilemmas.jsonl", base), "utf8").trim().split("\n").map(JSON.parse);
const evalIds = new Set(readFileSync(new URL("corpus/eval-ids.txt", base), "utf8").trim().split("\n"));
const teachers = ["teacher-gemini.jsonl", "teacher-claude.jsonl"].flatMap((f) => {
  const u = new URL("out/" + f, base);
  return existsSync(u) ? readFileSync(u, "utf8").trim().split("\n").map(JSON.parse) : [];
});

const GATE_SYS = "You are the gate for a decision app. Judge whether ACTING on the user's dilemma would hurt someone, damage property, or break the law - ordinary hard life choices pass as none - and classify what kind of decision it is. Reply with JSON: {\"mode\": binary|yesNo|tooBig|notADecision, \"risk\": none|selfHarm|harmOthers|illegal}. notADecision when there is no personal choice the user could act on: trivia, questions of fact, venting, statements, greetings.";
const qSys = (mode, a, b) =>
  `You write rapid-fire gut-check questions that bypass overthinking for a decision app. The user answers every question by tapping '${a}' or '${b}'. Every question must be answerable INSTANTLY by one of those taps${mode === "binary" ? " - forced-choice phrasing, never yes/no, never 'how much'" : " - direct yes/no questions only"}. Each question names a concrete detail of this exact dilemma. Never give advice. Never mention AI. Reply with JSON: {"optionA": string, "optionB": string, "questions": [8-10 strings]}.`;
const VERDICT_SYS = "You state the decision a user's own rapid-fire answers point to. You are a mirror: every claim must come from the answers. The decision is ONE imperative sentence naming the choice - never a question. The next step is one concrete physical action within 24 hours. Never mention AI. Reply with JSON: {\"decision\": string, \"sentiment\": DECIDED|SPLIT, \"analysis\": string, \"nextStep\": string}.";

// —— mechanical judge (mirror of FMEngine.obeysButtons + rubric limits) ——
const openBans = ["how many", "how much", "how often", "how important", "what ", "what's", "why ", "when ", "where "];
const ynStarts = ["do you", "did you", "does ", "have you", "has ", "are you", "is ", "was ", "were you", "would you", "will you", "can you", "could you", "should you"];
function questionOK(q, isBinary) {
  const s = q.toLowerCase();
  if (q.split(/\s+/).length > 12) return false;
  if (openBans.some((b) => s.startsWith(b))) return false;
  if (isBinary && ynStarts.some((b) => s.startsWith(b)) && !s.includes(" or ")) return false;
  return true;
}
function verdictOK(v) {
  if (!v.decision || v.decision.trim().endsWith("?")) return false;
  if (!["DECIDED", "SPLIT"].includes(v.sentiment)) return false;
  const next = (v.nextStep || "").toLowerCase();
  if (["decide", "consider", "reflect", "think about"].some((b) => next.startsWith(b))) return false;
  if ((v.analysis || "").split(".").filter((x) => x.trim()).length > 3) return false;
  return true;
}

const rows = [];
const stats = { gate: 0, questions: 0, verdicts: 0, rejectedQ: 0, rejectedV: 0, evalSkipped: 0 };

// Task 1: gate classification for EVERY corpus row (labels are the signal)
for (const r of corpus) {
  if (evalIds.has(r.id)) { stats.evalSkipped++; continue; }
  rows.push({ messages: [
    { role: "system", content: GATE_SYS },
    { role: "user", content: `Dilemma: ${r.dilemma}` },
    { role: "assistant", content: JSON.stringify({ mode: r.mode === "sensitive" ? (r.mode) : r.mode, risk: r.risk }) },
  ]});
  stats.gate++;
}

// Tasks 2+3: questions and verdicts from judged teacher records
const modeOf = Object.fromEntries(corpus.map((r) => [r.id, r.mode]));
for (const t of teachers) {
  if (evalIds.has(t.id)) { stats.evalSkipped++; continue; }
  const isBinary = modeOf[t.id] === "binary";
  if (t.kind === "questions") {
    const o = t.output;
    const kept = o.questions.filter((q) => questionOK(q, isBinary));
    if (kept.length < 6) { stats.rejectedQ++; continue; }
    rows.push({ messages: [
      { role: "system", content: qSys(modeOf[t.id], o.optionA ?? "No", o.optionB ?? "Yes") },
      { role: "user", content: `Dilemma: ${t.input.dilemma}` },
      { role: "assistant", content: JSON.stringify({ optionA: o.optionA ?? "No", optionB: o.optionB ?? "Yes", questions: kept }) },
    ]});
    stats.questions++;
  } else if (t.kind === "verdict") {
    if (!verdictOK(t.output)) { stats.rejectedV++; continue; }
    rows.push({ messages: [
      { role: "system", content: VERDICT_SYS },
      { role: "user", content: `Dilemma: ${t.input.dilemma}\n\nAnswers given under a 60-second clock:\n${t.input.transcript}\n\nState the verdict.` },
      { role: "assistant", content: JSON.stringify(t.output) },
    ]});
    stats.verdicts++;
  }
}

// Shuffle deterministically so task types interleave
let seed = 42;
const rand = () => (seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31;
rows.sort(() => rand() - 0.5);

mkdirSync(new URL("./out/", import.meta.url), { recursive: true });
writeFileSync(new URL("./out/train.jsonl", import.meta.url), rows.map((r) => JSON.stringify(r)).join("\n") + "\n");

// Eval pack: the sealed holdout dilemmas + labels (generation targets for judging)
const evalRows = corpus.filter((r) => evalIds.has(r.id));
writeFileSync(new URL("./out/eval-dilemmas.jsonl", import.meta.url), evalRows.map((r) => JSON.stringify(r)).join("\n") + "\n");

console.log(`train.jsonl: ${rows.length} examples`, stats);
console.log(`eval-dilemmas.jsonl: ${evalRows.length} sealed rows`);
