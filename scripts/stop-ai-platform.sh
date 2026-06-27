#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"

log "Stopping AI Platform..."

cd "$DOCKER_DIR"

docker compose \
    -f compose.inference.yml \
    -f compose.litellm.yml \
    -f compose.openwebui.yml \
    down

success "Containers stopped."
