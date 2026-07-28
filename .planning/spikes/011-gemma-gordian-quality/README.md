---
spike: 011
name: gemma-gordian-quality
type: standard
validates: "Given Gemma 3 1B LoRA-tuned on the 009 dataset, when evaluated on the sealed holdout vs untuned Gemma and the Gemini teacher, then tuned quality justifies on-device packaging via LiteRT-LM"
verdict: PENDING
related: [005, 009]
tags: [gemma, lora, litert-lm, on-device]
---

# Spike 011: Gemma Gordian Quality

## What This Validates
Phase 1 (quality): Gemma 3 1B + LoRA on the 009 dataset, judged on the sealed
53-row holdout against untuned Gemma and the Gemini teacher. Phase 2 (only if
phase 1 passes): convert to .litertlm and integrate via LiteRT-LM — Google's
edge runtime with iOS Metal support AND Android support (one tuned model
serves both apps' privacy tiers; successor to Apple's sunset adapter path).

## Assets
- out/train.jsonl — 731 chat-format examples (334 gate / 216 questions / 181
  verdicts), mechanical judge filters applied (37 teacher records rejected)
- out/eval-dilemmas.jsonl — 53 sealed holdout rows (never trained on)
- build-training-set.mjs — deterministic rebuild from 009 assets

## Founder prerequisites (phase 1)
1. Hugging Face account; accept the Gemma license on the google/gemma-3-1b-it
   model page; create a read token.
2. Colab (Pro recommended for an A100/L4; 1B QLoRA may squeeze onto free T4).

## Investigation Trail
- 2026-07-27: Apple adapter path invalidated (platform sunset). Founder chose
  Gemma; LiteRT-LM confirmed as runtime target (fine-tuned-model conversion
  tutorial exists; iOS + Android). Training set built.

## Results
PENDING — awaits Colab training run.
