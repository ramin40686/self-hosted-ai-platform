#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/ramin/ai-platform/models"

declare -A MODELS=(

["chat/Qwen2.5-7B-Instruct"]="Qwen/Qwen2.5-7B-Instruct"
["chat/Llama-3.1-8B-Instruct"]="meta-llama/Llama-3.1-8B-Instruct"
["chat/Gemma-2-9B-it"]="google/gemma-2-9b-it"
["chat/DeepSeek-R1-Distill-Qwen-7B"]="deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"

["coder/Qwen2.5-Coder-7B-Instruct"]="Qwen/Qwen2.5-Coder-7B-Instruct"
["coder/DeepSeek-Coder-V2-Lite"]="deepseek-ai/DeepSeek-Coder-V2-Lite"

["vision/Qwen2.5-VL-7B-Instruct"]="Qwen/Qwen2.5-VL-7B-Instruct"

["speech/whisper-large-v3"]="openai/whisper-large-v3"

["embedding/bge-m3"]="BAAI/bge-m3"
["embedding/jina-embeddings-v3"]="jinaai/jina-embeddings-v3"

["reranker/bge-reranker-v2-m3"]="BAAI/bge-reranker-v2-m3"

)

echo
echo "==========================================="
echo "Downloading AI models"
echo "Started : $(date)"
echo "==========================================="

for DEST in "${!MODELS[@]}"
do

MODEL="${MODELS[$DEST]}"

TARGET="$BASE/$DEST"

echo
echo "-------------------------------------------"
echo "Model : $MODEL"
echo "Target: $TARGET"
echo

mkdir -p "$TARGET"

hf download \
"$MODEL" \
--local-dir "$TARGET"

done

echo
echo "==========================================="
echo "Finished : $(date)"
echo "==========================================="
echo

du -sh "$BASE"/*
