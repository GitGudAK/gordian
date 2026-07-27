#!/usr/bin/env node
// Spike 009 — Teacher A: Gemini generates question sets and verdicts for the
// labeled corpus. Zero dependencies; run with Node 20+.
//
//   export GEMINI_DATASET_KEY=...   (fresh operator key — NEVER the proxy's,
//                                    never the burned spike-era key)
//   node gen-gemini.mjs [--limit N]
//
// Reads  corpus/dilemmas.jsonl
// Writes out/teacher-gemini.jsonl   ({id, teacher, kind, input, output})
//
// Only binary/yesNo rows get questions+verdict (gate rows exist to train the
// on-device gate; their labels are the training signal, no teacher needed).

import { readFileSync, mkdirSync, appendFileSync, existsSync } from "node:fs";

const KEY = process.env.GEMINI_DATASET_KEY;
if (!KEY) {
  console.error("GEMINI_DATASET_KEY is not set. Mint a fresh key in AI Studio and `export GEMINI_DATASET_KEY=...` first.");
  process.exit(1);
}

const MODEL = "gemini-3.5-flash";
const limitArg = process.argv.indexOf("--limit");
const LIMIT = limitArg > -1 ? Number(process.argv[limitArg + 1]) : Infinity;

const corpus = readFileSync(new URL("./corpus/dilemmas.jsonl", import.meta.url), "utf8")
  .trim().split("\n").map((l) => JSON.parse(l));

// Eval rows never receive teacher outputs — the adapter must not train on
// the dilemmas it will be measured against.
const evalIds = new Set(
  readFileSync(new URL("./corpus/eval-ids.txt", import.meta.url), "utf8").trim().split("\n")
);

mkdirSync(new URL("./out/", import.meta.url), { recursive: true });
const OUT = new URL("./out/teacher-gemini.jsonl", import.meta.url);
const done = new Set(
  existsSync(OUT)
    ? readFileSync(OUT, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l).id + ":" + JSON.parse(l).kind)
    : []
);

async function generate(system, user, schema) {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: user }] }],
        generationConfig: { responseMimeType: "application/json", responseSchema: schema },
      }),
    }
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const data = await res.json();
  const text = (data.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? "").join("");
  return JSON.parse(text);
}

// Prompts mirror the production proxy (operations.ts) — the teacher must
// speak the house style the adapter will learn.
function questionsSystem(mode, optionA, optionB) {
  const framing = mode === "binary"
    ? `Frame questions like 'Which one would you start tonight?' or 'Which would you regret never trying?' so each is answered by picking '${optionA}' or '${optionB}'. Never yes/no phrasing, never 'how much' phrasing.`
    : "Use direct yes/no phrasing only.";
  return (
    "You write rapid-fire, high-intensity bypass questions (maximum 12 words each) designed to bypass the analytical brain and force an immediate gut response. " +
    "CRITICAL: every question must be answerable INSTANTLY by tapping one of the two option buttons. " +
    framing +
    " Every question must name a concrete detail of the user's exact dilemma — its people, options, or stakes. Never give advice. Never mention AI."
  );
}

const VERDICT_SYSTEM =
  "You state the decision a user's own rapid-fire answers point to. You are a mirror: every claim must come from the answers, quoted or plainly restated. If the answers do not say it, you do not know it. The decision is ONE imperative sentence naming the choice — never a question. The next step is one concrete physical action doable within 24 hours — never 'decide', 'consider', or 'reflect'. Never mention AI.";

const QUESTIONS_SCHEMA = {
  type: "OBJECT",
  properties: {
    optionA: { type: "STRING", description: "First alternative as a Title Case button label, 1-3 words" },
    optionB: { type: "STRING", description: "Second alternative as a Title Case button label, 1-3 words" },
    questions: { type: "ARRAY", items: { type: "STRING" }, minItems: 8, maxItems: 10 },
  },
  required: ["optionA", "optionB", "questions"],
};

const VERDICT_SCHEMA = {
  type: "OBJECT",
  properties: {
    decision: { type: "STRING" },
    sentiment: { type: "STRING", enum: ["DECIDED", "SPLIT"] },
    analysis: { type: "STRING" },
    nextStep: { type: "STRING" },
  },
  required: ["decision", "sentiment", "analysis", "nextStep"],
};

// Deterministic pseudo-random answer pattern per id, so runs are reproducible
function answerPattern(id, questions, optionA, optionB) {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return questions.map((q, i) => {
    const pick = ((h >> i % 24) & 1) === 1;
    const hesitant = ((h >> (i + 7) % 24) & 3) === 0;
    return { question: q, choice: pick ? optionB : optionA, hesitant };
  });
}

let processed = 0;
for (const row of corpus) {
  if (processed >= LIMIT) break;
  if (row.mode !== "binary" && row.mode !== "yesNo") continue;
  if (evalIds.has(row.id)) continue;

  try {
    if (!done.has(row.id + ":questions")) {
      const q = await generate(
        questionsSystem(row.mode, "the first option", "the second option"),
        `Dilemma: ${row.dilemma}` +
          (row.mode === "binary"
            ? "\nExtract the two alternatives as short Title Case button labels (optionA, optionB), then write the questions so each is answered by picking one label."
            : "\nSet optionA to 'No' and optionB to 'Yes'."),
        QUESTIONS_SCHEMA
      );
      const optionA = row.mode === "binary" ? q.optionA : "No";
      const optionB = row.mode === "binary" ? q.optionB : "Yes";
      appendFileSync(OUT, JSON.stringify({ id: row.id, teacher: "gemini", kind: "questions", input: { dilemma: row.dilemma, mode: row.mode }, output: q }) + "\n");

      if (!done.has(row.id + ":verdict")) {
        const answers = answerPattern(row.id, q.questions, optionA, optionB);
        const transcript = answers
          .map((a) => `Q: ${a.question}\nA: ${a.choice}${a.hesitant ? " (hesitated)" : ""}`)
          .join("\n");
        const v = await generate(
          VERDICT_SYSTEM,
          `Dilemma: ${row.dilemma}\n\nAnswers given under a 60-second clock:\n${transcript}\n\nState the verdict.`,
          VERDICT_SCHEMA
        );
        appendFileSync(OUT, JSON.stringify({ id: row.id, teacher: "gemini", kind: "verdict", input: { dilemma: row.dilemma, transcript }, output: v }) + "\n");
      }
    }
    processed++;
    console.log(`[${processed}] ${row.id} ok`);
    await new Promise((r) => setTimeout(r, 400)); // stay friendly to rate limits
  } catch (err) {
    console.error(`[${row.id}] FAILED: ${err.message}`);
  }
}
console.log("Done. Output: out/teacher-gemini.jsonl");
