#!/usr/bin/env bash
set -u

CONFIG="/home/ramin/ai-platform/config/models.conf"
BASE="/home/ramin/ai-platform/models"

DOWNLOADED=0
SKIPPED=0
FAILED=0

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

    if [[ -f "$TARGET/config.json" ]]; then
        echo "✓ Already downloaded."
        ((SKIPPED++))
        continue
    fi

    if hf download "$MODEL" --local-dir "$TARGET"; then
        echo "✓ Downloaded."
        ((DOWNLOADED++))
    else
        echo "✗ Failed."
        ((FAILED++))
        rm -rf "$TARGET"
        continue
    fi

done < "$CONFIG"

echo
echo "==========================================="
echo "Finished : $(date)"
echo "==========================================="
echo

echo "Downloaded : $DOWNLOADED"
echo "Skipped    : $SKIPPED"
echo "Failed     : $FAILED"

echo
echo "Disk usage:"
du -sh "$BASE"/* 2>/dev/null
