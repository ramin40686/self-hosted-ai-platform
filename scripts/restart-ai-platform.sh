#!/usr/bin/env bash

DIR="$(dirname "$0")"

"$DIR/stop-ai-platform.sh"

"$DIR/start-ai-platform.sh"
