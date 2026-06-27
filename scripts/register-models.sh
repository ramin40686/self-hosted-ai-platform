#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="/home/ramin/ai-platform"
CONFIG="$ROOT/config/enabled-models.conf"
MODELS_DIR="$ROOT/models"

# Added variables (مرحله ۱)
AUTO_COMPOSE="$ROOT/docker/compose.inference.yml"
AUTO_LITELLM="$ROOT/litellm/config/config.yaml"

GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.92}"

########################################################
# GPU Scheduler
########################################################

# GPU IDs موجود
GPU_LIST=(0 1)

# ظرفیت هر GPU (GB)
GPU_TOTAL_VRAM[0]=24
GPU_TOTAL_VRAM[1]=24

# VRAM مصرف‌شده
GPU_USED_VRAM[0]=0
GPU_USED_VRAM[1]=0

# Allocated GPU (set by allocate_gpu)
ALLOCATED_GPU=""

########################################################
# Allocate GPU
########################################################

allocate_gpu() {

    local model_vram="$1"

    local best_gpu=-1
    local best_free=-1

    for gpu in "${GPU_LIST[@]}"
    do
        local used=${GPU_USED_VRAM[$gpu]:-0}
        local total=${GPU_TOTAL_VRAM[$gpu]:-0}
        local free=$((total-used))

        if (( free >= model_vram )); then
            if (( free > best_free )); then
                best_free=$free
                best_gpu=$gpu
            fi
        fi
    done

    if (( best_gpu == -1 )); then
        return 1
    fi

    # Update global state (no echo; avoid subshell issues)
    GPU_USED_VRAM[$best_gpu]=$((GPU_USED_VRAM[$best_gpu]+model_vram))
    ALLOCATED_GPU="$best_gpu"

    return 0
}

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

printf "\n${BLUE}"
echo "=============================================="
echo " AI Platform - Model Registry"
echo "=============================================="
printf "${NC}\n"

if [[ ! -f "$CONFIG" ]]; then
    echo -e "${RED}ERROR:${NC} $CONFIG not found."
    exit 1
fi

# Remove previous outputs if any (تغییر ۴)
rm -f "$AUTO_COMPOSE"
rm -f "$AUTO_LITELLM"

# We'll create the files after scheduling; but create headers now
cat > "$AUTO_COMPOSE" <<EOF
services:
EOF

cat > "$AUTO_LITELLM" <<EOF
model_list:
EOF

printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
TYPE MODEL STATE PRIORITY TP DEVICE VRAM STATUS

echo "-----------------------------------------------------------------------------------------------------------------------------"

TOTAL=0
FOUND=0
MISSING=0
DISABLED=0
NO_GPU=0

# Table of scheduled models (to be written to compose/litellm after scheduling)
declare -a SCHEDULED_MODELS

# Read sorted by PRIORITY (field 4) numeric ascending
while IFS='|' read -r TYPE MODEL STATE PRIORITY TP DEVICE VRAM
do
    [[ -z "$TYPE" ]] && continue
    [[ "$TYPE" =~ ^# ]] && continue

    ((++TOTAL))

    MODEL_NAME="$(basename "$MODEL")"
    MODEL_PATH="$MODELS_DIR/$TYPE/$MODEL_NAME"

    STATUS=""

    # 1) If disabled, mark disabled and continue
    if [[ "$STATE" == "off" ]]; then
        STATUS="DISABLED"
        ((++DISABLED))

        printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
            "$TYPE" "$MODEL_NAME" "$STATE" "$PRIORITY" "$TP" "$DEVICE" "$VRAM" "$STATUS"

        continue
    fi

    # 2) If model directory doesn't exist, mark missing and continue
    if [[ ! -d "$MODEL_PATH" ]]; then
        STATUS="MISSING"
        ((++MISSING))

        printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
            "$TYPE" "$MODEL_NAME" "$STATE" "$PRIORITY" "$TP" "$DEVICE" "$VRAM" "$STATUS"

        continue
    fi

    # Normalize VRAM to integer (GB). If VRAM empty or non-numeric => 0
    if [[ -z "$VRAM" ]]; then
        model_vram=0
    else
        model_vram=$(awk "BEGIN {print int($VRAM+0.5)}")
        model_vram=${model_vram:-0}
    fi

    # Prepare names
    MODEL_DIR=$(basename "$MODEL")
    SERVICE_NAME=$(echo "$MODEL_DIR" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g;s/^-//;s/-$//')
    CONTAINER_NAME="vllm-$SERVICE_NAME"

    ########################################################
    # GPU Scheduler usage for this model
    ########################################################

    if [[ "$DEVICE" == "auto" ]]; then

        allocate_gpu "$model_vram" || {
            STATUS="NO_GPU"
            ((++NO_GPU))

            printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
                "$TYPE" "$MODEL_NAME" "$STATE" "$PRIORITY" "$TP" "$DEVICE" "$VRAM" "$STATUS"

            continue
        }

        GPU_ID="$ALLOCATED_GPU"

    else
        # If DEVICE is numeric, use it; otherwise sanitize to digits
        GPU_ID=$(echo "$DEVICE" | sed 's/[^0-9]//g')
        GPU_ID=${GPU_ID:-0}

        # Check capacity before reserving
        current=${GPU_USED_VRAM[$GPU_ID]:-0}
        total=${GPU_TOTAL_VRAM[$GPU_ID]:-0}

        if (( current + model_vram > total )); then
            STATUS="NO_GPU"
            ((++NO_GPU))

            printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
                "$TYPE" "$MODEL_NAME" "$STATE" "$PRIORITY" "$TP" "$DEVICE" "$VRAM" "$STATUS"

            continue
        fi

        # Reserve VRAM on the chosen GPU
        GPU_USED_VRAM[$GPU_ID]=$((current + model_vram))
    fi

    # At this point allocation succeeded. Mark FOUND and record scheduling entry.
    STATUS="FOUND"
    ((++FOUND))

    # Save scheduled model entry for later compose/litellm generation
    # Fields: TYPE|MODEL_DIR|SERVICE_NAME|GPU_ID|TP|VRAM
    SCHEDULED_MODELS+=("$TYPE|$MODEL_DIR|$SERVICE_NAME|$GPU_ID|$TP|$VRAM")

    # Print status line now (FOUND)
    printf "%-12s %-45s %-10s %-8s %-8s %-10s %-10s %-10s\n" \
        "$TYPE" "$MODEL_NAME" "$STATE" "$PRIORITY" "$TP" "$DEVICE" "$VRAM" "$STATUS"

done < <(sort -s -t'|' -k4,4n "$CONFIG")

# After scheduling, generate compose and LiteLLM entries from SCHEDULED_MODELS
for entry in "${SCHEDULED_MODELS[@]}"
do
    IFS='|' read -r TYPE MODEL_DIR SERVICE_NAME GPU_ID TP VRAM <<< "$entry"
    CONTAINER_NAME="vllm-$SERVICE_NAME"

    cat >> "$AUTO_COMPOSE" <<EOF

  $CONTAINER_NAME:
    image: vllm/vllm-openai:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped

    gpus:
      - driver: nvidia
        device_ids: ["$GPU_ID"]
        capabilities: [gpu]

    environment:
      NVIDIA_VISIBLE_DEVICES: "$GPU_ID"
      NVIDIA_DRIVER_CAPABILITIES: compute,utility

    volumes:
      - $MODELS_DIR/$TYPE:/models

    command: >
      --model /models/$MODEL_DIR
      --served-model-name $MODEL_DIR
      --host 0.0.0.0
      --port 8000
      --tensor-parallel-size $TP
      --gpu-memory-utilization $GPU_MEMORY_UTILIZATION

    expose:
      - "8000"

    healthcheck:
      test: ["CMD","curl","-f","http://localhost:8000/v1/models"]
      interval: 15s
      timeout: 5s
      retries: 60

    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"

    networks:
      - ai-platform

EOF

    cat >> "$AUTO_LITELLM" <<EOF

  - model_name: $SERVICE_NAME
    litellm_params:
      model: openai/$MODEL_DIR
      api_base: http://$CONTAINER_NAME:8000/v1
      api_key: dummy

EOF

done

# Append networks block to compose
cat >> "$AUTO_COMPOSE" <<EOF

networks:
  ai-platform:
    name: ai-platform
EOF

# Append general settings to LiteLLM
cat >> "$AUTO_LITELLM" <<EOF

general_settings:
  master_key: os.environ/OPENAI_API_KEY
  telemetry: false
EOF

echo
echo "----------------------------------------------"
echo "Summary"
echo "----------------------------------------------"

echo "Total Models : $TOTAL"
echo "Available    : $FOUND"
echo "Missing      : $MISSING"
echo "Disabled     : $DISABLED"
echo "No GPU       : $NO_GPU"

echo
echo "GPU Usage"
echo "----------------------------------------------"

for gpu in "${GPU_LIST[@]}"
do
    echo "GPU$gpu : ${GPU_USED_VRAM[$gpu]} / ${GPU_TOTAL_VRAM[$gpu]} GB"
done

echo
# Final messages updated for Commit 4
echo "Commit 4 completed."
echo "Compose file generated."
echo "LiteLLM config generated."

# Print generated file paths
echo
echo "Generated:"
echo "  $AUTO_COMPOSE"
echo "  $AUTO_LITELLM"

