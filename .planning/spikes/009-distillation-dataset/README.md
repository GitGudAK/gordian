---
spike: 009
name: distillation-dataset
type: standard
validates: "Given the labeled corpus and two teachers (Gemini + Claude) with a judge pass, when sessions are batch-generated, then a toolkit-ready training set exists that encodes the house style"
verdict: PENDING
related: [005]
tags: [lora, adapter, distillation, dataset, foundation-models]
---

# Spike 009: Distillation Dataset (two teachers + judge)

## What This Validates
Given the labeled dilemma corpus and two teachers (Gemini via API, Claude
in-session), when question sets and verdicts are batch-generated and filtered
by a judge rubric, then a training set exists in Apple adapter-toolkit format
that encodes Gordian's house style (button-answerable questions, grounded
imperative verdicts, gate discipline).

## Corpus (corpus/dilemmas.jsonl — 218 labeled seeds, authored 2026-07-26)
- 70 binary, 70 yesNo, 20 tooBig, 15 notADecision
- 23 gate positives: 10 harm_others, 8 illegal, 5 self_harm (mild, non-graphic)
- 20 boundary NEGATIVES (spicy-but-allowed: confrontations, firing, no-contact,
  risky money) — includes e003, a regression seed for the historical
  "stab in unstable" false-positive lockout
- Labels (mode + risk) are the gate-training signal; teachers only generate
  questions/verdicts for binary/yesNo rows.

## Pipeline
1. `gen-gemini.mjs` — Teacher A. `export GEMINI_DATASET_KEY=...` (FRESH
   operator key; never the proxy secret, never the burned spike-era key),
   then `node gen-gemini.mjs [--limit N]`. Resumable; writes
   `out/teacher-gemini.jsonl`.
2. Teacher B: Claude, generated in-session in batches against the same corpus
   and schemas (or via ANTHROPIC_API_KEY variant of the script later).
3. Judge pass: Claude scores every example — binary questions answerable by
   the two buttons, ≤12 words, names dilemma specifics, verdict imperative +
   grounded only in transcript. Only passes enter training data.
4. Format for Apple's adapter toolkit (blocked on spike 008 proving the
   toolkit round-trip).

## ToS note (founder-acknowledged)
Both providers restrict output-use for training competing models; an
app-specific LoRA on Apple's base model is judged non-competing by the
founder. Operator keys are spend-capped.

## Investigation Trail
- 2026-07-26: Corpus authored (Claude, 218 seeds). Gemini teacher script
  written (zero-dep Node, resumable, deterministic answer patterns).
  Awaiting fresh operator key to run.

## Results
PENDING — corpus and Teacher A tooling ready; generation not yet run.
