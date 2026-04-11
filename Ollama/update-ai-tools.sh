#!/bin/bash
echo "=== Updating Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh

echo "=== Updating AnythingLLM ==="
ANYTHING_LLM_INSTALL_DIR=/opt/anythingllm sudo -E bash -c 'curl -fsSL https://raw.githubusercontent.com/Mintplex-Labs/anything-llm/master/docker/scripts/installer.sh | bash'

echo "=== Done ==="
