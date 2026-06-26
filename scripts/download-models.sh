#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG="/home/ramin/ai-platform/config/models.conf"
BASE="/home/ramin/ai-platform/models"

echo
echo "==========================================="
echo "Downloading AI models"
echo "Started : $(date)"
echo "==========================================="

while IFS='|' read -r TYPE MODEL
do
    [[ -z "$TYPE" ]] && continue
    [[ "$TYPE" =~ ^# ]] && continue

    NAME=$(basename "$MODEL")
    TARGET="$BASE/$TYPE/$NAME"

    echo
    echo "-------------------------------------------"
    echo "Model : $MODEL"
    echo "Target: $TARGET"

    mkdir -p "$TARGET"

    #===========================================
    # Skip if already downloaded
    #===========================================
    if [ -f "$TARGET/config.json" ]; then
        echo "✓ Already downloaded."
        continue
    fi

    #===========================================
    # Download model
    #===========================================
    hf download \
        "$MODEL" \
        --local-dir "$TARGET"

done < "$CONFIG"

echo
echo "==========================================="
echo "Finished : $(date)"
echo "==========================================="

du -sh "$BASE"/*

