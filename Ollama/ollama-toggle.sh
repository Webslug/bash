#!/bin/bash

MODELS_DIR="/media/storage/g/AI/models"

# --- STOP if already running ---
if systemctl is-active --quiet ollama; then
    sudo systemctl stop ollama
    zenity --info --title="Ollama" --text="Ollama stopped — VRAM freed"
    exit 0
fi

# --- BUILD MODEL LIST from gguf files ---
MODEL_ARGS=()
while IFS= read -r filepath; do
    filename=$(basename "$filepath")
    MODEL_ARGS+=(FALSE "$filename" "$filepath")
#done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.gguf" | sort)
done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.gguf" -printf "%T@ %p\n" | sort -rn | awk '{print $2}')

if [ ${#MODEL_ARGS[@]} -eq 0 ]; then
    zenity --error --title="Ollama" --text="No GGUF models found in $MODELS_DIR"
    exit 1
fi

# --- SELECT MODEL ---
SELECTED_PATH=$(zenity --list \
    --title="Select Model" \
    --text="Choose a model to load:" \
    --radiolist \
    --column="Select" \
    --column="Model" \
    --column="Path" \
    --hide-column=3 \
    --print-column=3 \
    "${MODEL_ARGS[@]}" \
    --width=700 --height=400)

if [ $? -ne 0 ] || [ -z "$SELECTED_PATH" ]; then
    exit 0
fi

SELECTED_NAME=$(basename "$SELECTED_PATH" .gguf | tr '[:upper:]' '[:lower:]' | tr ' _.' '-')

# --- SELECT THINKING MODE ---
THINK_CHOICE=$(zenity --list \
    --title="Thinking Mode" \
    --text="Select thinking mode for this session:" \
    --radiolist \
    --column="Select" \
    --column="Mode" \
    --column="Description" \
    TRUE  "thinking_on"  "Thinking enabled (default — slower, more accurate)" \
    FALSE "thinking_off" "Thinking disabled (faster, less reasoning)" \
    --width=500 --height=250)

if [ $? -ne 0 ]; then
    exit 0
fi

# --- START OLLAMA ---
sudo systemctl start ollama
sleep 1

# --- DETECT CHAT TEMPLATE BY MODEL FAMILY ---
case "${SELECTED_PATH,,}" in
    *gemma*)
        TEMPLATE_THINK='<start_of_turn>user\n{{ .Prompt }}<end_of_turn>\n<start_of_turn>model\n'
        TEMPLATE_NOTHINK='<start_of_turn>user\n{{ .Prompt }}<end_of_turn>\n<start_of_turn>model\n<think>\n\n</think>\n'
        STOP1="<end_of_turn>"
        STOP2="<start_of_turn>"
        ;;
    *qwen*|*hauhaucs*)
        TEMPLATE_THINK='<|im_start|>system\n{{ .System }}<|im_end|>\n<|im_start|>user\n{{ .Prompt }}<|im_end|>\n<|im_start|>assistant\n'
        TEMPLATE_NOTHINK='<|im_start|>system\n{{ .System }}<|im_end|>\n<|im_start|>user\n{{ .Prompt }}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n'
        STOP1="<|im_end|>"
        STOP2="<|endoftext|>"
        ;;
    *mistral*|*mixtral*)
        TEMPLATE_THINK='[INST] {{ .Prompt }} [/INST]'
        TEMPLATE_NOTHINK='[INST] {{ .Prompt }} [/INST]'
        STOP1="[INST]"
        STOP2=""
        ;;
    *llama*)
        TEMPLATE_THINK='<|start_header_id|>user<|end_header_id|>\n{{ .Prompt }}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n'
        TEMPLATE_NOTHINK="$TEMPLATE_THINK"
        STOP1="<|eot_id|>"
        STOP2=""
        ;;
    *ministral*|*mistral*)
        TEMPLATE_THINK='[INST] {{ .Prompt }} [/INST]'
        TEMPLATE_NOTHINK="$TEMPLATE_THINK"
        STOP1="[INST]"
        STOP2=""
        ;;
    *)
        TEMPLATE_THINK='### Human: {{ .Prompt }}\n### Assistant:'
        TEMPLATE_NOTHINK="$TEMPLATE_THINK"
        STOP1="### Human:"
        STOP2=""
        ;;
esac

# --- SELECT ACTIVE TEMPLATE ---
if [ "$THINK_CHOICE" = "thinking_off" ]; then
    ACTIVE_TEMPLATE="$TEMPLATE_NOTHINK"
    MODE_TEXT="Thinking DISABLED (fast mode)"
else
    ACTIVE_TEMPLATE="$TEMPLATE_THINK"
    MODE_TEXT="Thinking ENABLED (default mode)"
fi

# --- WRITE MODELFILE ---
MODELFILE="/tmp/Modelfile_$$"
echo "FROM $SELECTED_PATH" > "$MODELFILE"
echo "TEMPLATE \"\"\"$ACTIVE_TEMPLATE\"\"\"" >> "$MODELFILE"
echo "PARAMETER stop \"$STOP1\"" >> "$MODELFILE"
[ -n "$STOP2" ] && echo "PARAMETER stop \"$STOP2\"" >> "$MODELFILE"
echo "PARAMETER num_gpu 99" >> "$MODELFILE"

# --- REGISTER MODEL WITH OLLAMA ---
ollama create "$SELECTED_NAME" -f "$MODELFILE"
rm -f "$MODELFILE"

zenity --info --title="Ollama" \
    --text="Ollama started\nModel: $SELECTED_NAME\n$MODE_TEXT\n\nSet this model as Active in AnythingLLM to use it."
