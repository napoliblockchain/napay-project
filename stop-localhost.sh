#!/usr/bin/env bash
# Ferma tutto lo stack locale: wallet (tutti i profili) e backoffice napay. Non rimuove container ne' volumi:
# dati MySQL, Redis e chain restano per il prossimo avvio.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
docker compose --profile '*' stop
bash "$ROOT/napay/docker/local.sh" stop
printf '\nStack fermato. Riavvio: bash %s/start-localhost.sh\n' "$ROOT"
