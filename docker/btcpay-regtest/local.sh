#!/usr/bin/env bash
# SIP-022 B0: BTCPay regtest locale, separato dallo stack quotidiano. Uso:
#   bash docker/btcpay-regtest/local.sh {up|status|stop|reset --yes}
# Stato privato (0700/0600) in BTCPAY_LOCAL_STATE: percorso canonico, fuori dai checkout applicativi.
# Prima di aprire o creare qualunque file si verifica tipo, proprietario e permessi; nulla viene sovrascritto.
set -euo pipefail
umask 077
fail() { printf '%s\n' "$1" >&2; exit 1; }
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
root=$(CDPATH= cd -- "$dir/../.." && pwd -P)

# valori locali facoltativi (file ignorato da git): BTCPAY_LOCAL_STATE, BTCPAY_EDGE_NETWORK
if [[ -e $dir/.env || -L $dir/.env ]]; then
    [[ -f $dir/.env && ! -L $dir/.env && $(stat -c '%u' -- "$dir/.env") == "$(id -u)" ]] || fail 'docker/btcpay-regtest/.env must be a regular file owned by you.'
    [[ -n ${BTCPAY_LOCAL_STATE:-} ]] || BTCPAY_LOCAL_STATE=$(sed -n 's/^BTCPAY_LOCAL_STATE=//p' "$dir/.env" | tail -1)
    [[ -n ${BTCPAY_EDGE_NETWORK:-} ]] || BTCPAY_EDGE_NETWORK=$(sed -n 's/^BTCPAY_EDGE_NETWORK=//p' "$dir/.env" | tail -1)
fi
action=${1:-status}
case "$action" in
    up|status|stop) [[ $# -le 1 ]] ;;
    reset) [[ $# -eq 2 && $2 == --yes ]] || fail 'reset deletes all regtest data: use "reset --yes".' ;;
    *) false ;;
esac || fail 'Usage: bash docker/btcpay-regtest/local.sh {up|status|stop|reset --yes}'
edge=${BTCPAY_EDGE_NETWORK:-btcpay_regtest_edge}
[[ $edge =~ ^[a-z0-9][a-z0-9_.-]{0,62}$ ]] || fail 'Invalid BTCPAY_EDGE_NETWORK.'
# subnet fissa: il gateway rifiuta le richieste che arrivano dal backend BTCPay verso gli altri siti
subnet=${BTCPAY_EDGE_SUBNET:-10.252.0.0/24}
[[ $subnet =~ ^10\.[0-9]{1,3}\.[0-9]{1,3}\.0/24$ ]] || fail 'Invalid BTCPAY_EDGE_SUBNET (10.x.y.0/24).'
project=${BTCPAY_PROJECT:-btcpay-regtest}
[[ $project =~ ^[a-z0-9][a-z0-9_-]{0,62}$ ]] || fail 'Invalid BTCPAY_PROJECT.'

# --- percorso: canonico (niente "..", ".", symlink negli antenati o finali), fuori da questo checkout e dal principale
state=${BTCPAY_LOCAL_STATE:-}
[[ $state == /* && $state != *$'\n'* ]] || fail 'BTCPAY_LOCAL_STATE must be an absolute path.'
[[ $(realpath -m -- "$state") == "$state" ]] || fail 'BTCPAY_LOCAL_STATE must be canonical: no symlinks, "..", "." or trailing slash.'
forbidden=("$root")
common=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
[[ -z $common ]] || forbidden+=("$(realpath -m -- "$common/..")")
for checkout in "${forbidden[@]}"; do
    [[ $state != "$checkout" && $state != "$checkout/"* && $checkout != "$state/"* ]] \
        || fail 'BTCPAY_LOCAL_STATE must stay outside application checkouts.'
done

# --- cartella: creata solo da "up", poi ricontrollata dopo la creazione
if [[ $action == up && ! -e $state && ! -L $state ]]; then
    mkdir -p -m 700 -- "$state"
fi
[[ -d $state && ! -L $state ]] || fail 'Missing BTCPay regtest state: run "up" first.'
[[ $(realpath -e -- "$state") == "$state" && $(stat -c '%u' -- "$state") == "$(id -u)" ]] || fail 'BTCPAY_LOCAL_STATE must be your own real directory.'
chmod 700 -- "$state"
# lock sulla cartella stessa: nessun file da creare o troncare
exec 9<"$state"
flock -n 9 || fail 'Another BTCPay regtest operation is in progress.'

# 0 = presente e valido, 1 = assente; tutto il resto (symlink, altro tipo, proprietario, permessi, link multipli) = stop
private_file() {
    local path=$1 mode
    [[ ! -L $path ]] || fail "Refusing symlink: $path"
    [[ -e $path ]] || return 1
    [[ -f $path ]] || fail "Not a regular file: $path"
    [[ $(stat -c '%u' -- "$path") == "$(id -u)" && $(stat -c '%h' -- "$path") == 1 ]] || fail "Unexpected owner or links: $path"
    mode=$(stat -c '%a' -- "$path")
    (( (8#$mode & 077) == 0 )) || fail "Permissions too open: $path"
    return 0
}
# creazione atomica senza sovrascrittura: file temporaneo nuovo, poi link fisico che fallisce se il nome esiste
create_private() {
    local target=$1 tmp
    tmp=$(mktemp -- "$state/.new.XXXXXX")
    cat > "$tmp"
    ln -- "$tmp" "$target" 2>/dev/null || { rm -f -- "$tmp"; fail "Refusing to replace existing entry: $target"; }
    rm -f -- "$tmp"
}

# la cartella convenzionale sta in un repository di documenti: nulla va versionato
if ! private_file "$state/.gitignore"; then
    [[ $action == up ]] || fail 'Missing .gitignore in BTCPAY_LOCAL_STATE: run "up" first.'
    printf '*\n' | create_private "$state/.gitignore"
fi
grep -qx '\*' -- "$state/.gitignore" || fail '.gitignore in BTCPAY_LOCAL_STATE must ignore everything ("*").'
if ! private_file "$state/regtest.env"; then
    [[ $action == up ]] || fail 'Missing regtest.env: run "up" first.'
    password=$(openssl rand -hex 32)
    create_private "$state/regtest.env" <<ENV
POSTGRES_PASSWORD=$password
BTCPAY_POSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=btcpayserver;Database=btcpayserverregtest
BTCPAY_EXPLORERPOSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=btcpayserver;MaxPoolSize=80;Database=nbxplorerregtest
NBXPLORER_POSTGRES=User ID=btcpay;Password=$password;Host=postgres;Port=5432;Application Name=nbxplorer;MaxPoolSize=20;Database=nbxplorerregtest
ENV
    unset password
    private_file "$state/regtest.env" || fail 'regtest.env not created.'
fi

export BTCPAY_LOCAL_STATE=$state BTCPAY_EDGE_NETWORK=$edge
compose=(docker compose -p "$project" -f "$dir/compose.yml")
cli=("${compose[@]}" exec -T bitcoind bitcoin-cli -datadir=/data -rpcport=43782)

case "$action" in
    up)
        # rete verso il gateway: deve essere la bridge interna attesa; una rete omonima diversa non viene toccata
        if docker network inspect "$edge" >/dev/null 2>&1; then
            props=$(docker network inspect -f '{{.Internal}} {{.Driver}} {{index .Labels "napay.btcpay-regtest"}} {{range .IPAM.Config}}{{.Subnet}}{{end}}' "$edge")
            [[ $props == "true bridge edge $subnet" ]] \
                || fail "Network $edge exists but is not the internal bridge $subnet labelled napay.btcpay-regtest=edge: left unchanged."
        else
            docker network create --internal --driver bridge --subnet "$subnet" --label napay.btcpay-regtest=edge "$edge" >/dev/null
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
