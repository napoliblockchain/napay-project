#!/usr/bin/env bash
# SIP-022 B0: BTCPay regtest locale, separato dallo stack quotidiano. Uso:
#   bash docker/btcpay-regtest/local.sh {up|status|stop|reset --yes}
# Stato privato (0700/0600) in BTCPAY_LOCAL_STATE, assoluto e fuori dal repository.
set -euo pipefail
umask 077
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$dir/../.." && pwd)
# valori locali facoltativi (file ignorato da git): BTCPAY_LOCAL_STATE, BTCPAY_EDGE_NETWORK
if [[ -f $dir/.env ]]; then
    [[ -n ${BTCPAY_LOCAL_STATE:-} ]] || BTCPAY_LOCAL_STATE=$(sed -n 's/^BTCPAY_LOCAL_STATE=//p' "$dir/.env" | tail -1)
    [[ -n ${BTCPAY_EDGE_NETWORK:-} ]] || BTCPAY_EDGE_NETWORK=$(sed -n 's/^BTCPAY_EDGE_NETWORK=//p' "$dir/.env" | tail -1)
fi
state=${BTCPAY_LOCAL_STATE:-}
[[ $state == /* && $state != *$'\n'* ]] || { echo 'BTCPAY_LOCAL_STATE must be an absolute path.' >&2; exit 1; }
[[ $state != "$root" && $state != "$root/"* ]] || { echo 'BTCPAY_LOCAL_STATE must stay outside the repository.' >&2; exit 1; }
edge=${BTCPAY_EDGE_NETWORK:-btcpay_regtest_edge}
[[ $edge =~ ^[a-z0-9][a-z0-9_.-]{0,62}$ ]] || { echo 'Invalid BTCPAY_EDGE_NETWORK.' >&2; exit 1; }
project=${BTCPAY_PROJECT:-btcpay-regtest}
[[ $project =~ ^[a-z0-9][a-z0-9_-]{0,62}$ ]] || { echo 'Invalid BTCPAY_PROJECT.' >&2; exit 1; }
action=${1:-status}
case "$action" in
    up|status|stop) [[ $# -le 1 ]] ;;
    reset) [[ $# -eq 2 && $2 == --yes ]] || { echo 'reset deletes all regtest data: use "reset --yes".' >&2; exit 1; } ;;
    *) false ;;
esac || { echo 'Usage: bash docker/btcpay-regtest/local.sh {up|status|stop|reset --yes}' >&2; exit 1; }

[[ ! -L $state ]] || exit 1
mkdir -p "$state"
[[ $(stat -c '%u' "$state") == "$(id -u)" ]] || exit 1
chmod 700 "$state"
# la cartella convenzionale sta in un repository di documenti: nulla va versionato
[[ -e $state/.gitignore ]] || printf '*\n' > "$state/.gitignore"
exec 9>"$state/control.lock"
flock -n 9 || { echo 'Another BTCPay regtest operation is in progress.' >&2; exit 1; }

if [[ $action == up && ! -e $state/regtest.env ]]; then
    password=$(openssl rand -hex 32)
    cat > "$state/regtest.env" <<ENV
POSTGRES_PASSWORD=$password
BTCPAY_POSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=btcpayserver;Database=btcpayserverregtest
BTCPAY_EXPLORERPOSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=btcpayserver;MaxPoolSize=80;Database=nbxplorerregtest
NBXPLORER_POSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=nbxplorer;MaxPoolSize=20;Database=nbxplorerregtest
ENV
    unset password
fi
if [[ $action != reset ]]; then
    [[ -f $state/regtest.env && ! -L $state/regtest.env && $(stat -c '%u' "$state/regtest.env") == "$(id -u)" ]] || { echo 'Missing regtest.env: run "up" first.' >&2; exit 1; }
    mode=$(stat -c '%a' "$state/regtest.env")
    (( (8#$mode & 077) == 0 )) || exit 1
fi

export BTCPAY_LOCAL_STATE=$state BTCPAY_EDGE_NETWORK=$edge
compose=(docker compose -p "$project" -f "$dir/compose.yml")
cli=("${compose[@]}" exec -T bitcoind bitcoin-cli -datadir=/data -rpcport=43782)

case "$action" in
    up)
        # rete verso il gateway: interna, creata qui se manca (la usera il master per btcpay.local)
        if ! docker network inspect "$edge" >/dev/null 2>&1; then
            docker network create --internal --label napay.btcpay-regtest=edge "$edge" >/dev/null
        fi
        "${compose[@]}" config --quiet
        "${compose[@]}" up -d --wait --wait-timeout 240 postgres bitcoind nbxplorer
        # regtest parte in download iniziale: 101 blocchi lo sbloccano (una volta sola, dati persistenti)
        height=$("${cli[@]}" getblockcount)
        if (( height < 101 )); then
            "${cli[@]}" -named createwallet wallet_name=b0 load_on_startup=true >/dev/null 2>&1 || "${cli[@]}" loadwallet b0 >/dev/null 2>&1 || true
            address=$("${cli[@]}" -rpcwallet=b0 getnewaddress)
            "${cli[@]}" generatetoaddress $((101 - height)) "$address" >/dev/null
        fi
        "${compose[@]}" up -d --wait --wait-timeout 300 btcpayserver
        "${compose[@]}" ps --format '{{.Service}} {{.Status}}'
        ;;
    status)
        "${compose[@]}" ps --format '{{.Service}} {{.Status}}'
        ;;
    stop)
        "${compose[@]}" stop
        ;;
    reset)
        # unico comando distruttivo: container e volumi di questo progetto; segreti e rete restano
        "${compose[@]}" down --volumes --timeout 30
        ;;
esac
