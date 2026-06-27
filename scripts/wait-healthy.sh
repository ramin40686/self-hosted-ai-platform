#!/usr/bin/env bash
set -Eeuo pipefail

TIMEOUT="${TIMEOUT:-300}"
INTERVAL="${INTERVAL:-5}"
START_TIME=$(date +%s)

QUIET=false

if [[ "${1:-}" == "--quiet" ]]; then
    QUIET=true
    shift
fi

if ! $QUIET; then
    echo "=============================================="
    echo " Waiting for Healthy Containers"
    echo "=============================================="
fi

#
# اگر پارامتر داده شده همان‌ها بررسی می‌شوند.
# در غیر اینصورت سرویس‌ها از compose خوانده می‌شوند.
#
if (( $# > 0 )); then
    CONTAINERS=("$@")
else
    mapfile -t CONTAINERS < <(
        docker compose \
            -f docker/compose.inference.yml \
            -f docker/compose.litellm.yml \
            -f docker/compose.openwebui.yml \
            config --services
    )
fi

if (( ${#CONTAINERS[@]} == 0 )); then
    echo "No services found."
    exit 1
fi

declare -A LAST_STATUS

while true
do
    ALL_OK=true

    for C in "${CONTAINERS[@]}"
    do
        STATUS=""

        #
        # Container exists?
        #
        if ! docker inspect "$C" >/dev/null 2>&1
        then
            STATUS="not-found"
            ALL_OK=false

        else

            RUNNING=$(docker inspect \
                --format='{{.State.Running}}' \
                "$C")

            if [[ "$RUNNING" != "true" ]]
            then
                STATUS="stopped"
                ALL_OK=false

            else

                HEALTH=$(docker inspect \
                    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
                    "$C")

                case "$HEALTH" in

                    healthy)
                        STATUS="healthy"
                        ;;

                    none)
                        STATUS="running"
                        ;;

                    starting)
                        STATUS="starting"
                        ALL_OK=false
                        ;;

                    *)
                        STATUS="$HEALTH"
                        ALL_OK=false
                        ;;

                esac
            fi
        fi

        #
        # فقط در صورت تغییر وضعیت چاپ شود.
        #
        if ! $QUIET && [[ "${LAST_STATUS[$C]:-}" != "$STATUS" ]]
        then
            LAST_STATUS[$C]="$STATUS"

            case "$STATUS" in
                healthy)
                    printf "✓ %-35s healthy\n" "$C"
                    ;;

                running)
                    printf "✓ %-35s running\n" "$C"
                    ;;

                starting)
                    printf "... %-33s starting\n" "$C"
                    ;;

                not-found)
                    printf "✗ %-35s not found\n" "$C"
                    ;;

                stopped)
                    printf "✗ %-35s stopped\n" "$C"
                    ;;

                *)
                    printf "✗ %-35s %s\n" "$C" "$STATUS"
                    ;;
            esac
        fi

    done

    if $ALL_OK
    then
        if ! $QUIET; then
            echo
            echo "=============================================="
            echo "All requested containers are ready."
            echo "=============================================="
        fi
        exit 0
    fi

    NOW=$(date +%s)

    if (( NOW - START_TIME >= TIMEOUT ))
    then

        echo
        echo "=============================================="
        echo "ERROR: Timeout (${TIMEOUT}s)"
        echo "=============================================="

        for C in "${CONTAINERS[@]}"
        do

            if ! docker inspect "$C" >/dev/null 2>&1
            then
                echo
                echo "------------------------------------------------------------"
                echo "Container : $C"
                echo "Status    : NOT FOUND"
                echo "------------------------------------------------------------"
                continue
            fi

            HEALTH=$(docker inspect \
                --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
                "$C")

            if [[ "$HEALTH" != "healthy" && "$HEALTH" != "none" ]]
            then
                echo
                echo "------------------------------------------------------------"
                echo "Container : $C"
                echo "Health    : $HEALTH"
                echo "------------------------------------------------------------"
                docker logs --tail 30 "$C" || true
            fi
        done

        echo
        echo "============================================================"
        echo "Container Status"
        echo "============================================================"

        docker ps -a \
            --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

        exit 1
    fi

    sleep "$INTERVAL"

done

