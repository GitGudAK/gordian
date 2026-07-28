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
1. Drive folder Gordian-011/ with train.jsonl + eval-dilemmas.jsonl (from out/).
2. Colab (Pro recommended). Kaggle account (Google sign-in) with the Gemma 3
   license accepted + API token — replaces Hugging Face entirely.

## Investigation Trail
- 2026-07-27: Apple adapter path invalidated (platform sunset). Founder chose
  Gemma; LiteRT-LM confirmed as runtime target (fine-tuned-model conversion
  tutorial exists; iOS + Android). Training set built.
- 2026-07-27: Eval frame set by founder: tuned Gemma vs GEMINI on the sealed
  holdout (Apple base model out of scope). Gemini reference column banked
  (out/eval-gemini.jsonl, 32 sessionable rows; gate rows judged vs labels).
- 2026-07-27: No-HF pipeline per founder: Kaggle weights -> Colab LoRA ->
  local merge -> litert-torch export_hf on the local dir. Official tutorial
  fine-tunes Gemma 270M, so BOTH 270m and 1b train in one run (~200MB vs
  ~700MB on-device if the small one passes). colab_train_gemma.py ready.

## Results
PENDING — awaits Colab training run.
