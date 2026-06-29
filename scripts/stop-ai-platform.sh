#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/common.sh"

COMPOSE_DIR="$DOCKER_DIR"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --compose-dir)
            COMPOSE_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "Stopping AI Platform..."

docker compose \
    --project-name ai-platform \
    --env-file "$COMPOSE_DIR/.env" \
    -f "$COMPOSE_DIR/compose.inference.yml" \
    -f "$COMPOSE_DIR/compose.litellm.yml" \
    -f "$COMPOSE_DIR/compose.openwebui.yml" \
    down --remove-orphans

success "Containers stopped."
