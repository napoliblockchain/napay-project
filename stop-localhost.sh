#!/usr/bin/env bash
# Ferma tutti i container dello stack locale (tutti i profili). Non rimuove container ne' volumi:
# dati MySQL, Redis e chain restano per il prossimo avvio.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
docker compose --profile '*' stop
printf '\nStack fermato. Riavvio: bash %s/start-localhost.sh\n' "$ROOT"
