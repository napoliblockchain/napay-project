#!/usr/bin/env bash
# SIP-022 B0: prova dello stack regtest con progetto, rete edge e stato privato temporanei.
# Non tocca lo stack regtest persistente ne il gateway; pulisce solo le risorse di questa esecuzione.
set -euo pipefail
umask 077
dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run=$(openssl rand -hex 4)
export BTCPAY_PROJECT="btcpay-regtest-test-$run" BTCPAY_EDGE_NETWORK="btcpay_regtest_test_$run"
BTCPAY_LOCAL_STATE=$(mktemp -d); export BTCPAY_LOCAL_STATE
local_sh=(bash "$dir/local.sh")
compose=(docker compose -p "$BTCPAY_PROJECT" -f "$dir/compose.yml")
client=$(sed -n 's/^ *image: \(nicolasdorier\/nbxplorer:.*\)$/\1/p' "$dir/compose.yml")
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
cleanup() {
    code=$?
    trap - EXIT
    "${local_sh[@]}" reset --yes >/dev/null 2>&1 || true
    docker network rm "$BTCPAY_EDGE_NETWORK" >/dev/null 2>&1 || true
    rm -rf "$BTCPAY_LOCAL_STATE"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
http() { docker run --rm --network "$BTCPAY_EDGE_NETWORK" --entrypoint curl "$client" -sS -m 10 "$@"; }

"${local_sh[@]}" up >/dev/null
pass 'Stack up: postgres, bitcoind, nbxplorer, btcpayserver healthy'

config=$("${compose[@]}" config --format json)
grep -q '"published"' <<<"$config" && exit 1
pass 'No host ports published'
[[ $(grep -c '"image": ' <<<"$config") -eq 4 && $(grep -c '"image": "[^"]*@sha256:[0-9a-f]\{64\}"' <<<"$config") -eq 4 ]]
pass 'All images pinned by digest'
[[ $(stat -c '%a' "$BTCPAY_LOCAL_STATE") == 700 && $(stat -c '%a' "$BTCPAY_LOCAL_STATE/regtest.env") == 600 && -f $BTCPAY_LOCAL_STATE/.gitignore ]]
pass 'Private state 0700, secrets 0600, local .gitignore'

http -f http://btcpay-regtest:49392/api/v1/health | grep -q '"synchronized":true'
pass 'Health endpoint synchronized via edge network'
# il contratto OpenAPI della 2.4.7 richiede autenticazione: lo scarica la verifica B0 con l'utente admin
[[ $(http -o /dev/null -w '%{http_code}' http://btcpay-regtest:49392/swagger/v1/swagger.json) == 401 ]]
pass 'OpenAPI not public (401 without credentials)'

for service in postgres bitcoind nbxplorer btcpayserver; do
    "${compose[@]}" exec -T "$service" sh -c 'command -v bash >/dev/null && exec bash -c "timeout 5 bash -c \"exec 3<>/dev/tcp/1.1.1.1/443\"" || exec timeout 5 sh -c "nc -z 1.1.1.1 443"' >/dev/null 2>&1 && exit 1
done
pass 'No container reaches the internet'
http -f -o /dev/null http://bitcoind:43782/ 2>/dev/null && exit 1
pass 'Node RPC not reachable from the edge network'

height=$("${compose[@]}" exec -T bitcoind bitcoin-cli -datadir=/data -rpcport=43782 getblockcount)
(( height >= 101 ))
"${local_sh[@]}" stop >/dev/null
"${local_sh[@]}" up >/dev/null
[[ $("${compose[@]}" exec -T bitcoind bitcoin-cli -datadir=/data -rpcport=43782 getblockcount) == "$height" ]]
pass 'Stop/up keeps chain data, no extra mining'

"${local_sh[@]}" reset >/dev/null 2>&1 && exit 1
pass 'Reset refused without --yes'
"${local_sh[@]}" reset --yes >/dev/null
[[ -z $(docker volume ls -q --filter "label=com.docker.compose.project=$BTCPAY_PROJECT") ]]
pass 'Reset --yes removes only this project volumes'
printf 'PASS %d BTCPay regtest stack checks\n' "$checks"
