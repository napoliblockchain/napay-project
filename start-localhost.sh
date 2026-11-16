#!/usr/bin/env bash
# Avvio locale di tutto lo stack: wallet (poawallet) con chain Besu e backoffice napay. Solo sviluppo.
# Un solo gateway su 127.0.0.1 (80/443, oppure porte proprie dietro un proxy SNI locale che tiene 80/443):
# https://wallet.local e https://napay.local, senza porte.
# Non cancella volumi o fa git pull. Wallet: migration manuali; Napay: bootstrap automatico.
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
# cartella privata della sandbox (local.env, password, CA): NAPAY_LOCAL_STATE nel .env, fuori dai repository
NAPAY_STATE="$(env_value NAPAY_LOCAL_STATE)"
NAPAY_STATE="${NAPAY_STATE:-$HOME/.local/share/napay/browser-local}"
export NAPAY_LOCAL_STATE="$NAPAY_STATE"
LOCAL_NETWORK=napay_local_browser
# rete interna del server POS: subnet fissa, l'API /api/pos/* è accettata dal gateway solo da qui (SIP-021)
POS_NETWORK=pos_local_browser
# rete interna backoffice <-> chain di sviluppo: Napay legge i pagamenti TTS del POS (SIP-021 fase 3)
CHAIN_NETWORK=napay_local_chain
POS_SUBNET=10.251.0.0/24
BTCPAY_EDGE_NETWORK=btcpay_regtest_edge
BTCPAY_EDGE_SUBNET=10.252.0.0/24
BTCPAY_CLIENT_NETWORK=btcpay_regtest_client

step 'Prerequisiti'
docker info >/dev/null 2>&1 || fail 'Docker non attivo o non accessibile al tuo utente.'
[[ -f .env ]] || fail "manca $ROOT/.env (copia da .env.example)."
[[ -f poawallet/.env ]] || fail "manca $ROOT/poawallet/.env (copia da poawallet/.env.example)."
# SIP-029: password dell'utente DB dell'indicizzatore, generata una volta in una cartella privata fuori dai repository
WALLET_INDEXER_SECRET_FILE="$(env_value WALLET_INDEXER_SECRET_FILE)"
WALLET_INDEXER_SECRET_FILE="${WALLET_INDEXER_SECRET_FILE:-$ROOT/../napay-local-data/wallet-indexer/db-password}"
export WALLET_INDEXER_SECRET_FILE
if [[ ! -f "$WALLET_INDEXER_SECRET_FILE" ]]; then
  (umask 077; mkdir -p "$(dirname "$WALLET_INDEXER_SECRET_FILE")" && openssl rand -hex 24 > "$WALLET_INDEXER_SECRET_FILE") \
    || fail 'impossibile creare la password dell indicizzatore wallet.'
fi
# SIP-029 passo 2: chiave dei ticket /events, letta da Apache (www-data) e dal servizio Go: file 0644 in cartella 0700
WALLET_REALTIME_KEY_FILE="$(env_value WALLET_REALTIME_KEY_FILE)"
WALLET_REALTIME_KEY_FILE="${WALLET_REALTIME_KEY_FILE:-$ROOT/../napay-local-data/wallet-realtime/push-key}"
export WALLET_REALTIME_KEY_FILE
if [[ ! -f "$WALLET_REALTIME_KEY_FILE" ]]; then
  (umask 077; mkdir -p "$(dirname "$WALLET_REALTIME_KEY_FILE")" && openssl rand -hex 32 > "$WALLET_REALTIME_KEY_FILE" && chmod 644 "$WALLET_REALTIME_KEY_FILE") \
    || fail 'impossibile creare la chiave del tempo reale wallet.'
fi
[[ "$(stat -c %a "$(dirname "$WALLET_REALTIME_KEY_FILE")")" == 700 ]] || fail "la cartella di $WALLET_REALTIME_KEY_FILE deve essere 700."
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
HTTP_PORT="$(env_value GATEWAY_HTTP_PORT)"
HTTPS_PORT="$(env_value GATEWAY_HTTPS_PORT)"
[[ "$HTTP_PORT" =~ ^[1-9][0-9]{0,4}$ && "$HTTPS_PORT" =~ ^[1-9][0-9]{0,4}$ && "$HTTP_PORT" != "$HTTPS_PORT" ]] \
  || fail 'in .env servono GATEWAY_HTTP_PORT e GATEWAY_HTTPS_PORT numerici e distinti (vedi .env.example).'
# porte diverse da 80/443: gli URL senza porta passano da un proxy SNI locale su 127.0.0.1:80/443
BEHIND_PROXY=false
[[ "$HTTP_PORT" == 80 && "$HTTPS_PORT" == 443 ]] || BEHIND_PROXY=true
if ! docker ps --format '{{.Names}}' | grep -qx napay-gateway; then
  for port in "$HTTP_PORT" "$HTTPS_PORT"; do
    ! ss -ltnH "sport = :$port" 2>/dev/null | grep -q . \
      || fail "porta $port gia' occupata da un altro servizio (es. altro progetto): fermalo prima."
  done
fi
if [[ -f "$ROOT/napay/docker-compose.roles.yml" ]]; then
  # Older checkouts lack this overlay; once installed, role preflight is mandatory.
  if [[ ! -f "$NAPAY_STATE/local.env" ]]; then
    $CHECK && fail 'prima installazione Napay: --check non genera credenziali; avvia senza --check con NAPAY_IMPORT_DIR revisionato.'
    bash "$ROOT/napay/docker/local.sh" init || fail 'preparazione privata Napay fallita; nessun servizio avviato.'
  fi
  bash "$ROOT/napay/docker/local.sh" check \
    || fail 'preflight Napay fallito; nessun servizio avviato. Per sandbox legacy, prepara prima i ruoli come da LOCAL-BROWSER.md.'
fi
printf 'OK.\n'
$CHECK && { printf 'Solo verifica: nessun servizio avviato.\n'; exit 0; }

# rete interna gateway <-> backoffice: nessuna uscita Internet
docker network inspect "$LOCAL_NETWORK" >/dev/null 2>&1 \
  || docker network create --internal --label napay.service=browser-local "$LOCAL_NETWORK" >/dev/null
docker network inspect "$CHAIN_NETWORK" >/dev/null 2>&1 \
  || docker network create --internal --label napay.service=chain-local "$CHAIN_NETWORK" >/dev/null
docker network inspect "$POS_NETWORK" >/dev/null 2>&1 \
  || docker network create --internal --subnet "$POS_SUBNET" --label napay.service=pos-local "$POS_NETWORK" >/dev/null
[[ "$(docker network inspect "$POS_NETWORK" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')" == "$POS_SUBNET" ]] \
  || fail "la rete $POS_NETWORK esiste con una subnet diversa da $POS_SUBNET."
# Match B0 launcher identity and the subnet rejected by the Caddy backend guard.
btcpay_network() {
  local name=$1 label=$2 subnet=${3:-} props
  if docker network inspect "$name" >/dev/null 2>&1; then
    props=$(docker network inspect -f '{{.Internal}} {{.Driver}} {{index .Labels "napay.btcpay-regtest"}} {{range .IPAM.Config}}{{.Subnet}}{{end}}' "$name")
    [[ $props == "true bridge $label "* && ( -z $subnet || $props == "true bridge $label $subnet" ) ]] \
      || fail "rete $name incompatibile: non modificata (richiesta bridge interna napay.btcpay-regtest=$label $subnet)."
  else
    local -a args=(network create --internal --driver bridge --label "napay.btcpay-regtest=$label")
    [[ -z $subnet ]] || args+=(--subnet "$subnet")
    docker "${args[@]}" "$name" >/dev/null
  fi
}
btcpay_network "$BTCPAY_EDGE_NETWORK" edge "$BTCPAY_EDGE_SUBNET"
btcpay_network "$BTCPAY_CLIENT_NETWORK" client
compose config --quiet || fail 'configurazione docker compose non valida.'

if $BUILD; then
  step 'Build immagini (cache Docker)'
  compose build wallet-web chain-deploy wallet-realtime
fi

step '1/5 MySQL e Redis'
compose up -d --wait mysql-main redis-main

step '2/5 Chain di sviluppo Besu + token TTS'
compose up -d --wait besu
# one-shot rieseguibile: se il token esiste gia' non fa nulla
compose run --rm chain-deploy >/dev/null
# indirizzo del token TTS di sviluppo: al wallet (SIP-032) e al backoffice napay (passo 4)
TTS_TOKEN="$(docker exec wallet-besu cat /data/tts.json | sed -n 's/.*"address": *"\(0x[0-9a-fA-F]\{40\}\)".*/\1/p')"
[[ "$TTS_TOKEN" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail 'indirizzo del token TTS non leggibile dalla chain di sviluppo.'
export WALLET_TTS_TOKEN_ADDRESS="$TTS_TOKEN"
printf 'Chain pronta.\n'

step '3/5 Wallet'
compose up -d --wait --no-deps wallet-web
# migration mai automatiche (SIP-014): solo avviso
if ! docker exec wallet-web php yii migrate/new --interactive=0 2>/dev/null | grep -q 'No new migrations'; then
  printf 'ATTENZIONE: migration da applicare. Esegui:\n  docker exec -it wallet-web php yii migrate\n'
  printf 'Indicizzatore wallet non avviato finché le migration non sono applicate.\n'
else
  # SIP-029: utente DB a permessi minimi (SQL da stdin: la password non finisce negli argomenti dei processi)
  db_name="$(env_value MYSQL_DATABASE)"
  [[ "$db_name" =~ ^[A-Za-z0-9_]+$ ]] || fail 'MYSQL_DATABASE non valido.'
  indexer_password="$(tr -d '\n' < "$WALLET_INDEXER_SECRET_FILE")"
  [[ "$indexer_password" =~ ^[0-9a-f]{48}$ ]] || fail "password dell'indicizzatore non valida in $WALLET_INDEXER_SECRET_FILE."
  {
    printf "CREATE USER IF NOT EXISTS 'wallet_indexer'@'%%' IDENTIFIED BY '%s';\n" "$indexer_password"
    printf "ALTER USER 'wallet_indexer'@'%%' IDENTIFIED BY '%s';\n" "$indexer_password"
    # SIP-032: token dalle variabili d'ambiente, l'indicizzatore legge solo i wallet degli utenti
    printf "REVOKE IF EXISTS SELECT ON \`%s\`.\`%s\` FROM 'wallet_indexer'@'%%' IGNORE UNKNOWN USER;\n" "$db_name" nodes "$db_name" smart_contract "$db_name" blockchains
    printf "GRANT SELECT ON \`%s\`.\`mp_wallets\` TO 'wallet_indexer'@'%%';\n" "$db_name"
    for table in transactions chain_index_cursors; do printf "GRANT SELECT, INSERT, UPDATE ON \`%s\`.\`%s\` TO 'wallet_indexer'@'%%';\n" "$db_name" "$table"; done
    for table in mp_notifications mp_notifications_readers; do printf "GRANT SELECT, INSERT ON \`%s\`.\`%s\` TO 'wallet_indexer'@'%%';\n" "$db_name" "$table"; done
  } | docker exec -i mysql-main sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot' \
    || fail "utente DB dell'indicizzatore non creato."
  unset indexer_password
  compose up -d --wait --no-deps wallet-realtime
  printf 'Indicizzatore wallet attivo.\n'
fi

step '4/5 Backoffice napay'
# SIP-021 fase 3: Napay legge chain e token di sviluppo (rete napay_local_chain); mai scritti in local.env
export NAPAY_LOCAL_TTS_RPC_URL=http://wallet-besu:8545 NAPAY_LOCAL_TTS_CHAIN_ID=2118 NAPAY_LOCAL_TTS_TOKEN_ADDRESS="$TTS_TOKEN"
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
  # verifica diretta sul gateway, indipendente dal proxy
  curl --noproxy '*' --fail --silent --output /dev/null --cacert "$CA" --connect-to "::127.0.0.1:$HTTPS_PORT" \
    --retry 15 --retry-connrefused --retry-delay 2 --retry-all-errors "$url" \
    || fail "$url non risponde (docker logs napay-gateway)."
done

printf '\nPronto:\n  Wallet:     https://wallet.local\n  Backoffice: https://napay.local (email browser-admin@example.invalid, password in %s/browser-password)\n' "$NAPAY_STATE"
printf '  CA locale da importare una volta nel browser: %s\n' "$CA"
$BEHIND_PROXY && printf '  Gateway su 127.0.0.1:%s/%s: gli URL senza porta richiedono il proxy SNI locale attivo su 80/443.\n' "$HTTP_PORT" "$HTTPS_PORT"
printf 'Stop: bash %s/stop-localhost.sh\n' "$ROOT"
