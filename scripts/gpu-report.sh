#!/usr/bin/env bash
set -Eeuo pipefail

GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo
printf "${BLUE}"
echo "=============================================================="
echo "                AI Platform GPU Report"
echo "=============================================================="
printf "${NC}"

printf "%-35s %-6s %-10s\n" "Container" "GPU" "Status"
echo "--------------------------------------------------------------"

docker ps --format '{{.Names}}' \
| grep '^vllm-' \
| while read -r container
do
    gpu=$(docker inspect "$container" \
        --format '{{range .Config.Env}}{{println .}}{{end}}' \
        | grep NVIDIA_VISIBLE_DEVICES \
        | cut -d= -f2)

    status=$(docker inspect "$container" \
        --format '{{.State.Health.Status}}' 2>/dev/null || echo "running")

    printf "%-35s %-6s %-10s\n" \
        "$container" \
        "$gpu" \
        "$status"
done

echo
echo "=============================================================="
echo "GPU Memory"
echo "=============================================================="

nvidia-smi \
--query-gpu=index,name,memory.used,memory.total \
--format=csv,noheader,nounits \
| while IFS=',' read -r gpu name used total
do
    used=$(echo "$used" | xargs)
    total=$(echo "$total" | xargs)
    free=$((total-used))

    printf "\nGPU%s  (%s)\n" "$gpu" "$name"
    echo "--------------------------------------------------"

    printf "Used : %5d MiB\n" "$used"
    printf "Free : %5d MiB\n" "$free"
    printf "Total: %5d MiB\n" "$total"

    echo
    echo "Processes"

    nvidia-smi \
      --query-compute-apps=gpu_uuid,pid,used_memory \
      --format=csv,noheader,nounits \
      | while IFS=',' read -r uuid pid mem
        do
            proc_gpu=$(nvidia-smi \
                --query-compute-apps=gpu_uuid,pid \
                --format=csv,noheader \
                | grep "$pid" \
                | head -1)

            [[ -z "$proc_gpu" ]] && continue

            cname=$(docker ps --format '{{.ID}} {{.Names}}' \
                | while read id name
                  do
                    cpid=$(docker inspect "$id" \
                        --format '{{.State.Pid}}')

                    if [[ "$cpid" == "$pid" ]]; then
                        echo "$name"
                    fi
                  done)

            if [[ -n "$cname" ]]; then
                printf "  %-30s %6s MiB\n" "$cname" "$mem"
            fi
        done
done

echo
