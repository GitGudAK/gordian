# Spike 011 v2 — Gemma 3 270M only. Staged, self-aborting, no surprises.
#
# WHAT CHANGED vs v1 (each item is a v1 failure, fixed):
#  1. Prompt/completion dataset -> TRL masks the prompt, so the model is never
#     rewarded for reproducing the instructions. v1 trained on the whole
#     sequence, and every target began with '{"' -> it learned to emit
#     '{"{"{"...' forever.
#  2. LR 2e-4 -> 5e-5, epochs 3 -> 2. v1's settings were aggressive enough to
#     collapse a 270M model onto a single pattern.
#  3. Plain tokenizer call for generation (returns a dict, used as **enc).
#     v1 used apply_chat_template's return value positionally -> KeyError.
#  4. System text merged into the user turn (Gemma templates are finicky about
#     system roles), and eval prompts are built by the SAME function as
#     training prompts -> train/eval parity by construction.
#  5. STAGE GATES: the script proves the pipeline on a handful of examples and
#     ABORTS before the expensive run if anything is off. No blind spending.
#
# RUN: files train.jsonl + eval-dilemmas.jsonl in /content, then %run this.

import json, re, os, sys
from pathlib import Path

WORK = Path("/content"); OUT = WORK / "out"; OUT.mkdir(exist_ok=True)
MODEL_CANDIDATES = ["unsloth/gemma-3-270m-it", "google/gemma-3-270m-it"]

for f in ("train.jsonl", "eval-dilemmas.jsonl"):
    if not (WORK / f).exists():
        sys.exit(f"ABORT: missing /content/{f}")

train_rows = [json.loads(l) for l in (WORK / "train.jsonl").read_text().splitlines()]
eval_rows = [json.loads(l) for l in (WORK / "eval-dilemmas.jsonl").read_text().splitlines()]
print(f"train={len(train_rows)} eval={len(eval_rows)}")

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig
from trl import SFTConfig, SFTTrainer
from datasets import Dataset

MODEL = None
for ref in MODEL_CANDIDATES:
    try:
        AutoTokenizer.from_pretrained(ref); MODEL = ref; break
    except Exception as e:
        print(f"  {ref} unreachable: {type(e).__name__}")
if MODEL is None:
    sys.exit("ABORT: no reachable 270M weights")
print("model:", MODEL)

tok = AutoTokenizer.from_pretrained(MODEL)

# ---- single source of truth for prompt text (training AND eval) ----
def build_prompt(msgs):
    """msgs = [{system}, {user}] -> prompt string ending at the assistant turn."""
    system = next((m["content"] for m in msgs if m["role"] == "system"), "")
    user = next(m["content"] for m in msgs if m["role"] == "user")
    merged = (system + "\n\n" + user).strip() if system else user
    return tok.apply_chat_template(
        [{"role": "user", "content": merged}],
        tokenize=False, add_generation_prompt=True)

pairs = [{"prompt": build_prompt(r["messages"][:2]),
          "completion": r["messages"][2]["content"] + tok.eos_token}
         for r in train_rows]

# STAGE GATE 1 — data sanity before any GPU work
assert all(p["prompt"] and p["completion"] for p in pairs), "ABORT: empty prompt/completion"
lens = sorted(len(tok(p["prompt"] + p["completion"]).input_ids) for p in pairs)
print(f"STAGE1 ok | examples={len(pairs)} | token len p50={lens[len(lens)//2]} p95={lens[int(len(lens)*.95)]} max={lens[-1]}")
assert lens[-1] < 4096, "ABORT: examples longer than context"

def load_model():
    return AutoModelForCausalLM.from_pretrained(
        MODEL, dtype=torch.bfloat16, device_map="auto", attn_implementation="eager")

def gen(m, prompt_text, max_new=320):
    enc = tok(prompt_text, return_tensors="pt").to(m.device)
    out = m.generate(**enc, max_new_tokens=max_new, do_sample=False,
                     pad_token_id=tok.pad_token_id or tok.eos_token_id)
    return tok.decode(out[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).strip()

def parse_json(txt):
    m = re.search(r"\{.*\}", txt, re.S)
    if not m: return None
    try: return json.loads(m.group(0))
    except Exception: return None

# STAGE GATE 2 — prove the generation code path on the BASE model (cheap)
base = load_model()
probe = gen(base, pairs[0]["prompt"], 96)
print("STAGE2 base sample:", probe[:120].replace("\n", " "))
assert len(probe) > 0, "ABORT: generation produced nothing"
print("STAGE2 ok | generation path works")

def train(rows, epochs, tag):
    ds = Dataset.from_list(rows)
    lora = LoraConfig(r=16, lora_alpha=32, lora_dropout=0.05, task_type="CAUSAL_LM",
                      target_modules=["q_proj","k_proj","v_proj","o_proj",
                                      "gate_proj","up_proj","down_proj"])
    cfg = SFTConfig(output_dir=f"/content/{tag}", num_train_epochs=epochs,
                    per_device_train_batch_size=4, gradient_accumulation_steps=2,
                    learning_rate=5e-5, lr_scheduler_type="cosine", warmup_ratio=0.03,
                    logging_steps=25, bf16=True, report_to=[], max_length=2048,
                    save_strategy="no")
    tr = SFTTrainer(model=load_model(), args=cfg, train_dataset=ds, peft_config=lora)
    tr.train()
    return tr.model.merge_and_unload()

# STAGE GATE 3 — tiny train on 24 examples; must still emit parseable JSON.
# This is the check that would have caught v1's collapse for ~90 seconds of GPU.
smoke = train(pairs[:24], 1, "smoke")
sp = gen(smoke, pairs[0]["prompt"], 128)
print("STAGE3 smoke sample:", sp[:160].replace("\n", " "))
assert parse_json(sp) is not None, f"ABORT: smoke model emits unparseable output -> {sp[:200]}"
assert not re.search(r'(\{"){3,}', sp), "ABORT: degenerate repetition detected (v1 failure mode)"
print("STAGE3 ok | training path produces valid JSON")
del smoke; torch.cuda.empty_cache()

# ---- the real run ----
model = train(pairs, 2, "full")
mdir = OUT / "gemma3-270m-gordian-merged"
model.save_pretrained(str(mdir)); tok.save_pretrained(str(mdir))
print("merged ->", mdir)

sanity = gen(model, pairs[0]["prompt"], 128)
print("post-train sample:", sanity[:200].replace("\n", " "))
if parse_json(sanity) is None:
    print("WARNING: post-train output unparseable; eval will record it as-is")

# ---- eval both models on the sealed holdout ----
GATE_SYS = next(r["messages"][0]["content"] for r in train_rows if '"mode"' in r["messages"][0]["content"])
VERDICT_SYS = next(r["messages"][0]["content"] for r in train_rows if '"decision"' in r["messages"][0]["content"])

def q_sys(mode, a, b):
    tail = (" - forced-choice phrasing, never yes/no, never 'how much'"
            if mode == "binary" else " - direct yes/no questions only")
    return (f"You write rapid-fire gut-check questions that bypass overthinking for a decision app. "
            f"The user answers every question by tapping '{a}' or '{b}'. Every question must be "
            f"answerable INSTANTLY by one of those taps{tail}. Each question names a concrete detail "
            f"of this exact dilemma. Never give advice. Never mention AI. "
            f'Reply with JSON: {{"optionA": string, "optionB": string, "questions": [8-10 strings]}}.')

def answer_pattern(rid, questions, a, b):
    h = 0
    for c in rid: h = (h * 31 + ord(c)) & 0xFFFFFFFF
    return "\n".join(
        f"Q: {q}\nA: {b if (h >> (i % 24)) & 1 else a}" + (" (hesitated)" if ((h >> ((i+7) % 24)) & 3) == 0 else "")
        for i, q in enumerate(questions))

def run_eval(m, label):
    res = []
    for r in eval_rows:
        rec = {"id": r["id"], "dilemma": r["dilemma"],
               "expected_mode": r["mode"], "expected_risk": r["risk"]}
        rec["gate"] = gen(m, build_prompt([{"role":"system","content":GATE_SYS},
                                           {"role":"user","content":f"Dilemma: {r['dilemma']}"}]), 96)
        if r["mode"] in ("binary", "yesNo"):
            a, b = ("the first option", "the second option") if r["mode"] == "binary" else ("No", "Yes")
            qtxt = gen(m, build_prompt([{"role":"system","content":q_sys(r["mode"], a, b)},
                                        {"role":"user","content":f"Dilemma: {r['dilemma']}"}]), 320)
            rec["questions"] = qtxt
            qj = parse_json(qtxt)
            if qj and isinstance(qj.get("questions"), list) and qj["questions"]:
                oa, ob = qj.get("optionA", a), qj.get("optionB", b)
                tsc = answer_pattern(r["id"], qj["questions"], oa, ob)
                rec["verdict"] = gen(m, build_prompt([{"role":"system","content":VERDICT_SYS},
                    {"role":"user","content":f"Dilemma: {r['dilemma']}\n\nAnswers given under a 60-second clock:\n{tsc}\n\nState the verdict."}]), 256)
        res.append(rec)
    p = OUT / f"eval-270m-{label}.jsonl"
    p.write_text("\n".join(json.dumps(x) for x in res) + "\n")
    print(f"{label} eval -> {p} ({len(res)} rows)")
    return p

files_out = [run_eval(model, "tuned"), run_eval(base, "base")]

from google.colab import files as cf
for p in files_out:
    cf.download(str(p))
print("DONE — both eval files downloaded")
