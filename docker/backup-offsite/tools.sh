#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
    encrypt|upload) command=$1; shift; exec bash "$(dirname -- "$0")/$command.sh" "$@" ;;
    version) exec rclone version ;;
    *) printf 'Expected encrypt, upload or version.\n' >&2; exit 1 ;;
esac
