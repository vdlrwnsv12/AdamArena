#!/bin/bash
set -eu
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$KIT_DIR/prepare.sh" "$@"
