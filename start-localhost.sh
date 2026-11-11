#!/usr/bin/env bash
# Avvio locale del wallet (poawallet) con chain di sviluppo Besu. Solo sviluppo.
# Non cancella volumi, non esegue migration, non fa git pull: le stampa se servono.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD=false
CHECK=false
for argument in "$@"; do
  case "$argument" in
    --build) BUILD=true ;;
    --check) CHECK=true ;;
    --help|-h)
      printf '%s\n' 'Uso: bash start-localhost.sh [--build] [--check]' \
        '--build: ricostruisce le immagini (wallet-web, chain-tools) usando la cache Docker.' \
        '--check: verifica i prerequisiti senza avviare nulla.'
      exit 0 ;;
    *) printf 'Opzione sconosciuta: %s\n' "$argument" >&2; exit 1 ;;
  esac
done
fail() { printf '\nERRORE: %s\n' "$*" >&2; exit 1; }
step() { printf '\n=== %s ===\n' "$*"; }
trap 'printf "\nAvvio interrotto alla riga %s. Nessun volume cancellato.\n" "$LINENO" >&2' ERR

cd "$ROOT"
compose() { docker compose --profile chain "$@"; }
env_value() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d "\"'"; }

step 'Prerequisiti'
docker info >/dev/null 2>&1 || fail 'Docker non attivo o non accessibile al tuo utente.'
[[ -f .env ]] || fail "manca $ROOT/.env (copia da .env.example)."
[[ -f poawallet/.env ]] || fail "manca $ROOT/poawallet/.env (copia da poawallet/.env.example)."
grep -qE '^[^#]*[[:space:]]wallet\.local([[:space:]]|$)' /etc/hosts \
  || fail 'manca in /etc/hosts la riga: 127.0.0.1 wallet.local'
if $BUILD || ! docker image inspect napay/poawallet:dev napay/chain-tools:dev >/dev/null 2>&1; then
  docker buildx version >/dev/null 2>&1 || fail 'serve Docker Buildx: sudo apt-get install docker-buildx'
  BUILD=true
fi
HTTPS_PORT="$(env_value GATEWAY_HTTPS_PORT)"
[[ -n "$HTTPS_PORT" ]] || fail 'GATEWAY_HTTPS_PORT non impostata in .env.'
compose config --quiet || fail 'configurazione docker compose non valida.'
printf 'OK.\n'
$CHECK && { printf 'Solo verifica: nessun servizio avviato.\n'; exit 0; }

if $BUILD; then
  step 'Build immagini (cache Docker)'
  compose build wallet-web chain-deploy
fi

step '1/4 MySQL e Redis'
compose up -d --wait mysql-main redis-main

step '2/4 Chain di sviluppo Besu + token TTS'
compose up -d --wait besu
# one-shot rieseguibile: se il token esiste gia' non fa nulla
compose run --rm chain-deploy >/dev/null
printf 'Chain pronta.\n'

step '3/4 Wallet'
compose up -d --wait --no-deps wallet-web
# migration mai automatiche (TIP-014): solo avviso
if ! docker exec wallet-web php yii migrate/new --interactive=0 2>/dev/null | grep -q 'No new migrations'; then
  printf 'ATTENZIONE: migration da applicare. Esegui:\n  docker exec -it wallet-web php yii migrate\n'
fi

step '4/4 Gateway'
# --no-deps: napay-web non serve al wallet (il backoffice ha il suo stack)
compose up -d --no-deps gateway
URL="https://wallet.local:$HTTPS_PORT"
for ((attempt=0; attempt<30; attempt++)); do
  code=$(curl --noproxy '*' -ks -o /dev/null --max-time 3 -w '%{http_code}' \
    --resolve "wallet.local:$HTTPS_PORT:127.0.0.1" "$URL/robots.txt" || true)
  [[ "$code" == 200 ]] && break
  sleep 2
done
[[ "$code" == 200 ]] || fail "gateway non risponde su $URL (docker logs napay-gateway)."

printf '\nPronto: %s\n' "$URL"
printf 'Stop: bash %s/stop-localhost.sh\n' "$ROOT"
