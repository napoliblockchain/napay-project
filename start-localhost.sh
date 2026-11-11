#!/usr/bin/env bash
# Avvio locale di tutto lo stack: wallet (poawallet) con chain Besu e backoffice napay. Solo sviluppo.
# Un solo gateway su 127.0.0.1:80/443: https://wallet.local e https://napay.local, senza porte.
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
        '--build: ricostruisce le immagini del wallet (wallet-web, chain-tools) usando la cache Docker.' \
        '         Il backoffice napay ricostruisce sempre con la cache (napay/docker/local.sh).' \
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
# sandbox privata del backoffice (napay/docker/local.sh): config, password, CA locale esportata
NAPAY_STATE="$HOME/.local/share/napay/browser-local"
LOCAL_NETWORK=napay_local_browser

step 'Prerequisiti'
docker info >/dev/null 2>&1 || fail 'Docker non attivo o non accessibile al tuo utente.'
[[ -f .env ]] || fail "manca $ROOT/.env (copia da .env.example)."
[[ -f poawallet/.env ]] || fail "manca $ROOT/poawallet/.env (copia da poawallet/.env.example)."
for host in wallet.local napay.local; do
  grep -qE "^[^#]*[[:space:]]${host//./\\.}([[:space:]]|\$)" /etc/hosts \
    || fail "manca in /etc/hosts la riga: 127.0.0.1 wallet.local napay.local"
done
if $BUILD || ! docker image inspect napay/poawallet:dev napay/chain-tools:dev >/dev/null 2>&1; then
  docker buildx version >/dev/null 2>&1 || fail 'serve Docker Buildx: sudo apt-get install docker-buildx'
  BUILD=true
fi
[[ -f "$NAPAY_STATE/local.env" || -n "${NAPAY_IMPORT_DIR:-}" ]] \
  || fail 'primo avvio napay: imposta NAPAY_IMPORT_DIR=<dataset v2 revisionato> (vedi napay/docker/LOCAL-BROWSER.md).'
[[ "$(env_value GATEWAY_HTTPS_PORT)" == 443 && "$(env_value GATEWAY_HTTP_PORT)" == 80 ]] \
  || fail 'in .env servono GATEWAY_HTTP_PORT=80 e GATEWAY_HTTPS_PORT=443 (vedi .env.example).'
if ! docker ps --format '{{.Names}}' | grep -qx napay-gateway; then
  for port in 80 443; do
    ! ss -ltnH "sport = :$port" 2>/dev/null | grep -q . \
      || fail "porta $port gia' occupata da un altro servizio (es. altro progetto): fermalo prima."
  done
fi
printf 'OK.\n'
$CHECK && { printf 'Solo verifica: nessun servizio avviato.\n'; exit 0; }

# rete interna gateway <-> backoffice: nessuna uscita Internet
docker network inspect "$LOCAL_NETWORK" >/dev/null 2>&1 \
  || docker network create --internal --label napay.service=browser-local "$LOCAL_NETWORK" >/dev/null
compose config --quiet || fail 'configurazione docker compose non valida.'

if $BUILD; then
  step 'Build immagini (cache Docker)'
  compose build wallet-web chain-deploy
fi

step '1/5 MySQL e Redis'
compose up -d --wait mysql-main redis-main

step '2/5 Chain di sviluppo Besu + token TTS'
compose up -d --wait besu
# one-shot rieseguibile: se il token esiste gia' non fa nulla
compose run --rm chain-deploy >/dev/null
printf 'Chain pronta.\n'

step '3/5 Wallet'
compose up -d --wait --no-deps wallet-web
# migration mai automatiche (TIP-014): solo avviso
if ! docker exec wallet-web php yii migrate/new --interactive=0 2>/dev/null | grep -q 'No new migrations'; then
  printf 'ATTENZIONE: migration da applicare. Esegui:\n  docker exec -it wallet-web php yii migrate\n'
fi

step '4/5 Backoffice napay'
# launcher del progetto napay: build con cache, bootstrap DB, utente locale
bash "$ROOT/napay/docker/local.sh" up

step '5/5 Gateway (wallet.local, napay.local)'
# --no-deps: il backoffice gira nella sandbox napay (passo 4), non nel servizio napay-web
compose up -d --no-deps gateway
CA="$NAPAY_STATE/caddy-root.crt"
for ((attempt=0; attempt<30; attempt++)); do
  docker exec napay-gateway test -f /data/caddy/pki/authorities/local/root.crt && break
  sleep 1
done
# CA locale del gateway: da importare una volta nel browser
docker cp napay-gateway:/data/caddy/pki/authorities/local/root.crt "$CA" >/dev/null
chmod 600 "$CA"
for url in https://wallet.local/robots.txt https://napay.local/site/login; do
  curl --noproxy '*' --fail --silent --output /dev/null --cacert "$CA" \
    --retry 15 --retry-connrefused --retry-delay 2 --retry-all-errors "$url" \
    || fail "$url non risponde (docker logs napay-gateway)."
done

printf '\nPronto:\n  Wallet:     https://wallet.local\n  Backoffice: https://napay.local (email browser-admin@example.invalid, password in %s/browser-password)\n' "$NAPAY_STATE"
printf '  CA locale da importare una volta nel browser: %s\n' "$CA"
printf 'Stop: bash %s/stop-localhost.sh\n' "$ROOT"
