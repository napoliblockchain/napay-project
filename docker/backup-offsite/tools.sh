#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
    encrypt|upload|seal-set) command=$1; shift; exec bash "$(dirname -- "$0")/$command.sh" "$@" ;;
    version) exec rclone version ;;
    *) printf 'Expected encrypt, upload, seal-set or version.\n' >&2; exit 1 ;;
esac
