# Spike 011 — Gemma LoRA fine-tune + holdout eval, Colab edition.
# ============================================================
# HOW TO RUN (Colab, GPU runtime — A100/L4 ideal, T4 workable):
#   1. Drive: create folder  My Drive/Gordian-011/  containing:
#        train.jsonl, eval-dilemmas.jsonl   (from this spike's out/)
#   2. New Colab notebook -> Runtime > Change runtime type > GPU
#   3. First cell:  %pip install -q -U transformers peft trl accelerate bitsandbytes
#   4. Upload this file via the Files pane, then:  %run colab_train_gemma.py
#      (prompts once for Drive mount; weights pull anonymously from ungated mirrors)
# Outputs land in Drive/Gordian-011/out/: merged models + eval generations.
# ============================================================

import json, os, hashlib
from pathlib import Path

# ---------- Drive + Kaggle auth ----------
from google.colab import drive, files  # type: ignore
drive.mount("/content/drive")
WORK = Path("/content/drive/MyDrive/Gordian-011")
OUT = WORK / "out"; OUT.mkdir(parents=True, exist_ok=True)
assert (WORK / "train.jsonl").exists(), "Upload train.jsonl to Drive/Gordian-011/ first"

# Weights come from public ungated mirrors — no account, no token, anywhere.
# (Google's Gemma license still governs use of the weights.) First reachable
# candidate wins.
MODELS = {
    "gemma3-270m": ["unsloth/gemma-3-270m-it", "google/gemma-3-270m-it"],
    "gemma3-1b":   ["unsloth/gemma-3-1b-it", "google/gemma-3-1b-it"],
}

# ---------- data ----------
train_rows = [json.loads(l) for l in (WORK / "train.jsonl").read_text().splitlines()]
eval_rows = [json.loads(l) for l in (WORK / "eval-dilemmas.jsonl").read_text().splitlines()]
print(f"train={len(train_rows)}  eval={len(eval_rows)}")

# Deterministic answer pattern — EXACT port of the JS generator so transcripts
# match the Gemini reference column
def answer_pattern(row_id: str, questions, a: str, b: str) -> str:
    h = 0
    for c in row_id:
        h = (h * 31 + ord(c)) & 0xFFFFFFFF
    lines = []
    for i, q in enumerate(questions):
        pick = (h >> (i % 24)) & 1
        hes = ((h >> ((i + 7) % 24)) & 3) == 0
        lines.append(f"Q: {q}\nA: {b if pick else a}{' (hesitated)' if hes else ''}")
    return "\n".join(lines)

GATE_SYS = next(r["messages"][0]["content"] for r in train_rows
                if '"mode"' in r["messages"][0]["content"])
VERDICT_SYS = next(r["messages"][0]["content"] for r in train_rows
                   if '"decision"' in r["messages"][0]["content"])

def q_sys(mode, a, b):
    tail = (" - forced-choice phrasing, never yes/no, never 'how much'"
            if mode == "binary" else " - direct yes/no questions only")
    return (f"You write rapid-fire gut-check questions that bypass overthinking for a decision app. "
            f"The user answers every question by tapping '{a}' or '{b}'. Every question must be "
            f"answerable INSTANTLY by one of those taps{tail}. Each question names a concrete detail "
            f"of this exact dilemma. Never give advice. Never mention AI. "
            f'Reply with JSON: {{"optionA": string, "optionB": string, "questions": [8-10 strings]}}.')

# ---------- train + eval per model ----------
import torch  # noqa: E402
from transformers import AutoModelForCausalLM, AutoTokenizer  # noqa: E402
from peft import LoraConfig, get_peft_model  # noqa: E402
from trl import SFTConfig, SFTTrainer  # noqa: E402
from datasets import Dataset  # noqa: E402

def run(tag: str, candidates):
    print(f"\n===== {tag} =====")
    path = None
    for ref in candidates:
        try:
            AutoTokenizer.from_pretrained(ref)
            path = ref; break
        except Exception as e:
            print(f"  {ref} unavailable: {e}")
    assert path, f"no reachable weights for {tag}" 
    tok = AutoTokenizer.from_pretrained(path)
    small = "270m" in tag
    model = AutoModelForCausalLM.from_pretrained(
        path, torch_dtype=torch.bfloat16, device_map="auto", attn_implementation="eager")

    def fmt(row):
        return tok.apply_chat_template(row["messages"], tokenize=False)

    ds = Dataset.from_list(train_rows)
    lora = LoraConfig(r=16, lora_alpha=32, lora_dropout=0.05, task_type="CAUSAL_LM",
                      target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                                      "gate_proj", "up_proj", "down_proj"])
    cfg = SFTConfig(output_dir=f"/content/{tag}-lora", num_train_epochs=3 if small else 2,
                    per_device_train_batch_size=4 if small else 2,
                    gradient_accumulation_steps=2 if small else 4,
                    learning_rate=2e-4, lr_scheduler_type="cosine", warmup_ratio=0.05,
                    logging_steps=20, bf16=True, report_to=[], max_length=2048)
    trainer = SFTTrainer(model=model, args=cfg, train_dataset=ds,
                         formatting_func=fmt, peft_config=lora)
    trainer.train()

    merged = trainer.model.merge_and_unload()
    mdir = OUT / f"{tag}-gordian-merged"
    merged.save_pretrained(str(mdir)); tok.save_pretrained(str(mdir))
    print(f"merged model -> {mdir}")

    # ---- holdout generations: tuned AND untuned, same prompts ----
    base = AutoModelForCausalLM.from_pretrained(
        path, torch_dtype=torch.bfloat16, device_map="auto", attn_implementation="eager")

    def gen(m, system, user, max_new=512):
        msgs = [{"role": "system", "content": system}, {"role": "user", "content": user}]
        ids = tok.apply_chat_template(msgs, add_generation_prompt=True, return_tensors="pt").to(m.device)
        out = m.generate(ids, max_new_tokens=max_new, do_sample=False,
                         pad_token_id=tok.eos_token_id)
        return tok.decode(out[0][ids.shape[1]:], skip_special_tokens=True).strip()

    for label, m in (("tuned", merged), ("base", base)):
        results = []
        for r in eval_rows:
            rec = {"id": r["id"], "dilemma": r["dilemma"], "expected_mode": r["mode"],
                   "expected_risk": r["risk"]}
            rec["gate"] = gen(m, GATE_SYS, f"Dilemma: {r['dilemma']}", 128)
            if r["mode"] in ("binary", "yesNo"):
                a, b = ("the first option", "the second option") if r["mode"] == "binary" else ("No", "Yes")
                q_raw = gen(m, q_sys(r["mode"], a, b), f"Dilemma: {r['dilemma']}", 512)
                rec["questions"] = q_raw
                try:
                    qj = json.loads(q_raw[q_raw.find("{"):q_raw.rfind("}") + 1])
                    oa = qj.get("optionA", "No"); ob = qj.get("optionB", "Yes")
                    transcript = answer_pattern(r["id"], qj["questions"], oa, ob)
                    rec["verdict"] = gen(m, VERDICT_SYS,
                        f"Dilemma: {r['dilemma']}\n\nAnswers given under a 60-second clock:\n{transcript}\n\nState the verdict.", 384)
                except Exception as e:
                    rec["verdict_error"] = str(e)
            results.append(rec)
            print(f"  [{label}] {r['id']}")
        out_file = OUT / f"eval-{tag}-{label}.jsonl"
        out_file.write_text("\n".join(json.dumps(x) for x in results) + "\n")
        print(f"{label} eval -> {out_file}")

    del base, merged, model; torch.cuda.empty_cache()

for tag, ref in MODELS.items():
    run(tag, ref)

print("\nALL DONE. Download from Drive/Gordian-011/out/: the four eval-*.jsonl files "
      "and share them back for judging. Merged models stay in Drive for phase 2 "
      "(.litertlm export: uv tool install litert-torch; litert-torch export_hf "
      "--model=<merged dir> --output_dir=<out> --externalize_embedder).")
