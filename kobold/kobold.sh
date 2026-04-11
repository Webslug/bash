#!/bin/bash

KOBOLD_BIN="/home/kim/Downloads/koboldcpp-linux-x64"
MODEL_DIR="/media/storage/g/AI/models"
CONTEXTSIZE="16000"
GPULAYERS="90"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
RESET='\033[0m'

COLORS=("$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA" "$CYAN")
TTS_MODEL="/home/kim/Downloads/Qwen3-TTS-12Hz-1.7B-VoiceDesign-Q8_0.gguf"
TOKENIZER="/home/kim/Downloads/qwen3-tts-tokenizer-q8_0.gguf"

MODELS=(
  "L3-8B-Lunaris-v1-Q6_K.gguf"
  "L3-8B-Lunaris-v1-IQ2_S.gguf"
  "Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf"
  "L3-8B-Stheno-v3.2-abliterated.Q8_0.gguf"
  "Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf"
  "Ministral-3-8B-Reasoning-2512-Q8_0.gguf"
  "functiongemma-270m-it-UD-Q8_K_XL.gguf"
  "gemma-4-E4B-it-Q5_K_S.gguf"
  "Qwen3.5-9B.Q8_0.gguf"
)

clear
echo -e "${CYAN}========================================${RESET}"
echo -e "${CYAN}         Kobold Model Launcher          ${RESET}"
echo -e "${CYAN}========================================${RESET}"
echo

for i in "${!MODELS[@]}"; do
  COLOR_INDEX=$((RANDOM % ${#COLORS[@]}))
  echo -e "${COLORS[$COLOR_INDEX]}$((i+1)). ${MODELS[$i]}${RESET}"
done

echo
read -rp "Choose model [1-9]: " CHOICE

if ! [[ "$CHOICE" =~ ^[1-9]$ ]]; then
  echo -e "${RED}Invalid choice.${RESET}"
  exit 1
fi

MODEL="${MODELS[$((CHOICE-1))]}"

if [[ "$MODEL" == TODO-* ]]; then
  echo -e "${YELLOW}That slot is empty. Edit kobold.sh and add a real model filename.${RESET}"
  exit 1
fi

echo -e "${YELLOW}Stopping any running koboldcpp...${RESET}"
pkill -f koboldcpp
sleep 1
#--quantkv 1 #works but may cause tool error bugs
#--quantkv 3 # use for BF16, faster inference!
# --flashinference #buggy has never worked

# TTS STUFF - Works but it is slow, not worth using.
# --ttsmodel "$TTS_MODEL" --ttswavtokenizer "$TOKENIZER" --ttsgpu 

echo -e "${GREEN}Launching:${RESET} $MODEL"
"$KOBOLD_BIN" --model "$MODEL_DIR/$MODEL" --contextsize "$CONTEXTSIZE" --gpulayers "$GPULAYERS" --quantkv 3 --useswa

nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | awk -F', ' '{print $1 " / " $2 " MB used"}'

#L3-8B-Lunaris-v1-Q6_K.gguf
#L3-8B-Lunaris-v1-IQ2_S.gguf
#TinyAgent-7B-Q4_K_M.gguf
#L3-8B-Lunaris-v1-Q6_K.gguf
#L3-8B-Stheno-v3.2-abliterated.Q8_0.gguf
#
#
