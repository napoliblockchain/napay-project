#!/usr/bin/env bash
# SIP-022 B0: prova dello stack regtest con progetto, rete edge e stato privato temporanei.
# Non tocca lo stack regtest persistente ne il gateway; pulisce solo le risorse di questa esecuzione.
set -euo pipefail
umask 077
dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
for tool in docker openssl od realpath; do command -v "$tool" >/dev/null || { echo "FAIL: missing prerequisite $tool" >&2; exit 1; }; done
run=$(openssl rand -hex 4)
# subnet di test diversa da quella reale (10.252.0.0/24): nessun conflitto con lo stack persistente
export BTCPAY_PROJECT="btcpay-regtest-test-$run" BTCPAY_EDGE_NETWORK="btcpay_regtest_test_$run"
export BTCPAY_EDGE_SUBNET="10.254.$(( $(od -An -N1 -tu1 /dev/urandom) % 200 + 20 )).0/24"
BTCPAY_LOCAL_STATE=$(realpath -e -- "$(mktemp -d)"); export BTCPAY_LOCAL_STATE
sim="btcpay_regtest_test_${run}_sim"
caddy=caddy:2.8.4-alpine@sha256:af32e97399febea808609119bb21544d0265c58a02836576e32a2d082c262c17
local_sh=(bash "$dir/local.sh")
compose=(docker compose -p "$BTCPAY_PROJECT" -f "$dir/compose.yml")
client=$(sed -n 's/^ *image: \(nicolasdorier\/nbxplorer:.*\)$/\1/p' "$dir/compose.yml")
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
cleanup() {
    code=$?
    trap - EXIT
    "${local_sh[@]}" reset --yes >/dev/null 2>&1 || true
    docker rm -f "btcpay-regtest-test-$run-sentinel" >/dev/null 2>&1 || true
    docker network rm "$BTCPAY_EDGE_NETWORK" "$sim" >/dev/null 2>&1 || true
    rm -rf "$BTCPAY_LOCAL_STATE"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
http() { docker run --rm --network "$BTCPAY_EDGE_NETWORK" --entrypoint curl "$client" -sS -m 10 "$@"; }
# probe NETWORK curl-args... -> $out e $code (exit di curl); il client ha curl, verificato sotto
probe() {
    local net=$1; shift
    set +e
    out=$(docker run --rm --network "$net" --entrypoint curl "$client" -s --max-time 5 "$@" 2>/dev/null)
    code=$?
    set -e
}
ip_on() { docker inspect -f "{{(index .NetworkSettings.Networks \"$2\").IPAddress}}" "$1"; }
networks_of() { docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$1" | tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' '; }
docker run --rm --network none --entrypoint curl "$client" --version >/dev/null

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

regtest="${BTCPAY_PROJECT}_regtest"
for service in postgres bitcoind nbxplorer; do
    [[ $(networks_of "$("${compose[@]}" ps -q "$service")") == "$regtest " ]]
done
[[ $(networks_of "$("${compose[@]}" ps -q btcpayserver)") == "$BTCPAY_EDGE_NETWORK $regtest " ]]
[[ $(docker network inspect -f '{{.Internal}}' "$regtest") == true && $(docker network inspect -f '{{.Internal}}' "$BTCPAY_EDGE_NETWORK") == true ]]
pass 'Services only on internal networks (btcpayserver also on edge)'

# Internet simulata: sentinella su una bridge normale; controllo positivo prima dei negativi
docker network create "$sim" >/dev/null
docker run -d --name "btcpay-regtest-test-$run-sentinel" --network "$sim" "$caddy" caddy respond --listen :80 sentinel >/dev/null
sentinel_ip=$(ip_on "btcpay-regtest-test-$run-sentinel" "$sim")
for _ in $(seq 1 20); do probe "$sim" "http://$sentinel_ip/"; [[ $out == sentinel ]] && break; sleep 1; done
[[ $code == 0 && $out == sentinel ]]
pass 'Positive control: sentinel reachable from an ordinary bridge network'
for net in "$regtest" "$BTCPAY_EDGE_NETWORK"; do
    probe "$net" -o /dev/null -w '%{http_code}' "http://$sentinel_ip/"
    [[ ($code == 7 || $code == 28) && $out != *200* ]]
done
pass 'No route out of regtest and edge networks (sentinel IP unreachable)'

# RPC del nodo: raggiungibile (401) dalla rete regtest, connessione impossibile dalla edge sullo stesso IP
rpc_ip=$(ip_on "$("${compose[@]}" ps -q bitcoind)" "$regtest")
probe "$regtest" -o /dev/null -w '%{http_code}' --data '{}' "http://$rpc_ip:43782/"
[[ $out == 401 ]]
pass 'Positive control: node RPC answers 401 inside the regtest network'
probe "$BTCPAY_EDGE_NETWORK" -o /dev/null -w '%{http_code}' --data '{}' "http://$rpc_ip:43782/"
[[ ($code == 7 || $code == 28) && $out == 000 ]] || { echo "FAIL: RPC by IP from edge (curl $code, http ${out:0:3})" >&2; exit 1; }
probe "$BTCPAY_EDGE_NETWORK" "http://bitcoind:43782/"
[[ $code == 6 ]] || { echo "FAIL: RPC by name from edge (curl $code)" >&2; exit 1; }
pass 'Node RPC unreachable from the edge network (by IP and by name)'

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
