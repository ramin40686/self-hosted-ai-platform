#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DOCKER_DIR="$ROOT/docker"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

log() {
    echo -e "${BLUE}$*${NC}"
}

success() {
    echo -e "${GREEN}$*${NC}"
}

warn() {
    echo -e "${YELLOW}$*${NC}"
}

error() {
    echo -e "${RED}$*${NC}"
}
