#!/usr/bin/env python3
"""
make_gguf.py — Train LoRA adapters on a base model, merge, and produce a single GGUF file.

PIPELINE (5 stages):
  1. LOAD    — Pull base model in 4-bit
  2. ADAPT   — Attach LoRA adapters
  3. TRAIN   — Fine-tune on local dataset
  4. MERGE   — Flatten adapters into full-weight safetensors (16-bit)
  5. CONVERT — Two-phase GGUF production:
               a) convert_hf_to_gguf.py  →  intermediate f16 GGUF
               b) llama-quantize         →  final q4_k_m GGUF

All temp artifacts land in one folder. That folder is destroyed on completion.
You get exactly one file: the final GGUF in PROJECT_DIR.
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

# ============================================================
# CONFIGURATION — edit these, leave everything else alone
# ============================================================
PROJECT_DIR       = Path("/home/kim/my_ai_project")
DATA_FILE         = PROJECT_DIR / "data.json"
LLAMA_CPP_DIR     = Path.home() / ".unsloth" / "llama.cpp"
FINAL_GGUF_NAME   = "my_custom_model.Q4_K_M.gguf"
QUANTIZATION_TYPE = "Q4_K_M"

# Base model — swap this line to retrain on a different foundation
BASE_MODEL        = "unsloth/Llama-3.2-1B-instruct-bnb-4bit"
MAX_SEQ_LENGTH    = 2048

# LoRA config
LORA_RANK         = 16
LORA_ALPHA        = 16

# Training config
BATCH_SIZE        = 2
MAX_STEPS         = 60
LEARNING_RATE     = 2e-4

# ============================================================
# DERIVED PATHS — single temp folder, everything under it
# ============================================================
TEMP_DIR          = PROJECT_DIR / "_build_temp"
MERGED_WEIGHTS    = TEMP_DIR / "merged_16bit"
INTERMEDIATE_GGUF = TEMP_DIR / "intermediate_f16.gguf"
TRAIN_OUTPUT_DIR  = TEMP_DIR / "train_checkpoints"
FINAL_GGUF_PATH   = PROJECT_DIR / FINAL_GGUF_NAME

# llama.cpp tools
CONVERTER_SCRIPT  = LLAMA_CPP_DIR / "convert_hf_to_gguf.py"
QUANTIZER_BINARY  = LLAMA_CPP_DIR / "build" / "bin" / "llama-quantize"

# Fallback: older llama.cpp builds put binaries in different spots
QUANTIZER_FALLBACKS = [
    LLAMA_CPP_DIR / "llama-quantize",
    LLAMA_CPP_DIR / "quantize",
    LLAMA_CPP_DIR / "build" / "llama-quantize",
]

# ============================================================
# HELPERS
# ============================================================

def _banner(msg: str) -> None:
    bar = "=" * 60
    print(f"\n{bar}\n  {msg}\n{bar}")


def _abort(msg: str) -> None:
    print(f"\n!! ABORT: {msg}", file=sys.stderr)
    sys.exit(1)


def _run(cmd: list, label: str) -> None:
    """Run a subprocess. On failure, print what went wrong and abort."""
    print(f"  >> {' '.join(str(c) for c in cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        _abort(f"Stage [{label}] failed with exit code {result.returncode}")


def _find_quantizer() -> Path:
    """Locate the llama-quantize binary. Check primary path, then fallbacks."""
    if QUANTIZER_BINARY.is_file() and os.access(QUANTIZER_BINARY, os.X_OK):
        return QUANTIZER_BINARY
    for fallback in QUANTIZER_FALLBACKS:
        if fallback.is_file() and os.access(fallback, os.X_OK):
            return fallback
    # Last resort: check if it's on PATH
    from shutil import which
    on_path = which("llama-quantize")
    if on_path:
        return Path(on_path)
    _abort(
        f"Cannot find llama-quantize binary.\n"
        f"  Checked: {QUANTIZER_BINARY}\n"
        f"  Fallbacks: {[str(f) for f in QUANTIZER_FALLBACKS]}\n"
        f"  Also checked $PATH.\n\n"
        f"  FIX: cd {LLAMA_CPP_DIR} && cmake -B build && cmake --build build --config Release -j\n"
        f"  This will compile the quantizer you need."
    )


def _preflight_checks() -> Path:
    """Verify tools exist before we spend 10 minutes training."""
    _banner("PREFLIGHT CHECKS")

    if not DATA_FILE.is_file():
        _abort(f"Training data not found: {DATA_FILE}")

    if not CONVERTER_SCRIPT.is_file():
        _abort(
            f"convert_hf_to_gguf.py not found at: {CONVERTER_SCRIPT}\n"
            f"  FIX: cd ~/.unsloth && git clone --recursive https://github.com/ggerganov/llama.cpp"
        )

    quantizer = _find_quantizer()
    print(f"  Converter : {CONVERTER_SCRIPT}")
    print(f"  Quantizer : {quantizer}")
    print(f"  Data file : {DATA_FILE}")
    print(f"  Output    : {FINAL_GGUF_PATH}")
    print("  All clear.")
    return quantizer


def _cleanup() -> None:
    """Nuke the single temp directory. Leave only the final GGUF and source files."""
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)
        print(f"  Cleaned up: {TEMP_DIR}")


# ============================================================
# PIPELINE STAGES
# ============================================================

def stage_load():
    """Stage 1: Load the base model in 4-bit."""
    _banner("STAGE 1 — LOAD BASE MODEL")
    from unsloth import FastLanguageModel
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=BASE_MODEL,
        max_seq_length=MAX_SEQ_LENGTH,
        load_in_4bit=True,
    )
    return model, tokenizer


def stage_adapt(model):
    """Stage 2: Attach LoRA adapters."""
    _banner("STAGE 2 — ATTACH LoRA ADAPTERS")
    from unsloth import FastLanguageModel
    model = FastLanguageModel.get_peft_model(
        model,
        r=LORA_RANK,
        lora_alpha=LORA_ALPHA,
        bias="none",
    )
    return model


def stage_train(model, tokenizer):
    """Stage 3: Fine-tune on local dataset."""
    _banner("STAGE 3 — TRAIN")
    from datasets import load_dataset
    from trl import SFTTrainer
    from transformers import TrainingArguments

    dataset = load_dataset("json", data_files=str(DATA_FILE), split="train")

    def format_func(examples):
        texts = [
            f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n"
            f"{inst}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
            f"{out}<|eot_id|>"
            for inst, out in zip(examples["instruction"], examples["output"])
        ]
        return {"text": texts}

    dataset = dataset.map(format_func, batched=True)

    TRAIN_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        dataset_text_field="text",
        args=TrainingArguments(
            per_device_train_batch_size=BATCH_SIZE,
            max_steps=MAX_STEPS,
            learning_rate=LEARNING_RATE,
            bf16=True,
            output_dir=str(TRAIN_OUTPUT_DIR),
        ),
    )
    trainer.train()
    return model, tokenizer


def stage_merge(model, tokenizer):
    """Stage 4: Merge LoRA adapters into full 16-bit weights."""
    _banner("STAGE 4 — MERGE WEIGHTS (16-bit)")
    MERGED_WEIGHTS.mkdir(parents=True, exist_ok=True)
    model.save_pretrained_merged(
        str(MERGED_WEIGHTS),
        tokenizer,
        save_method="merged_16bit",
    )
    print(f"  Merged weights saved to: {MERGED_WEIGHTS}")


def stage_convert(quantizer: Path):
    """
    Stage 5: Two-phase GGUF conversion.
      Phase A — HuggingFace safetensors → f16 GGUF  (convert_hf_to_gguf.py)
      Phase B — f16 GGUF → Q4_K_M GGUF              (llama-quantize)
    """
    _banner("STAGE 5a — CONVERT HF → F16 GGUF")
    _run(
        [
            sys.executable,
            str(CONVERTER_SCRIPT),
            str(MERGED_WEIGHTS),
            "--outfile", str(INTERMEDIATE_GGUF),
            "--outtype", "f16",
        ],
        label="HF-to-GGUF-f16",
    )
    print(f"  Intermediate GGUF: {INTERMEDIATE_GGUF}")

    if not INTERMEDIATE_GGUF.is_file():
        _abort("Converter ran but produced no output file.")

    _banner("STAGE 5b — QUANTIZE F16 → Q4_K_M")
    _run(
        [
            str(quantizer),
            str(INTERMEDIATE_GGUF),
            str(FINAL_GGUF_PATH),
            QUANTIZATION_TYPE,
        ],
        label="quantize-to-Q4_K_M",
    )

    if not FINAL_GGUF_PATH.is_file():
        _abort("Quantizer ran but produced no output file.")

    size_mb = FINAL_GGUF_PATH.stat().st_size / (1024 * 1024)
    print(f"\n  DONE: {FINAL_GGUF_PATH}  ({size_mb:.1f} MB)")


# ============================================================
# MAIN
# ============================================================

def main():
    quantizer = _preflight_checks()

    try:
        model, tokenizer = stage_load()
        model = stage_adapt(model)
        model, tokenizer = stage_train(model, tokenizer)
        stage_merge(model, tokenizer)

        # Free GPU memory before conversion (we don't need the model anymore)
        del model, tokenizer
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        stage_convert(quantizer)

    finally:
        _banner("CLEANUP")
        _cleanup()

    _banner("MISSION COMPLETE")
    print(f"  Your GGUF: {FINAL_GGUF_PATH}")
    print(f"  Load it in KoboldCpp and go.\n")


if __name__ == "__main__":
    main()
