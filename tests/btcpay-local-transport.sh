#!/usr/bin/env bash
# Read-only probes of the running local B0 stack; never use production credentials.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ca=${NAPAY_CA_FILE:?Set NAPAY_CA_FILE to the existing local Caddy CA}
[[ $ca == /* && -f $ca ]] || { echo 'Invalid local CA file.' >&2; exit 1; }
client=$(sed -n 's/^ *image: \(nicolasdorier\/nbxplorer:.*\)$/\1/p' "$root/docker/btcpay-regtest/compose.yml")
[[ -n $client ]] || exit 1
[[ $(docker network inspect -f '{{.Internal}} {{.Driver}} {{index .Labels "napay.btcpay-regtest"}} {{range .IPAM.Config}}{{.Subnet}}{{end}}' btcpay_regtest_edge) == 'true bridge edge 10.252.0.0/24' ]]
[[ $(docker network inspect -f '{{.Internal}} {{.Driver}} {{index .Labels "napay.btcpay-regtest"}}' btcpay_regtest_client) == 'true bridge client' ]]
[[ $(docker network inspect -f '{{.Internal}}' napay-browser-local_egress) == true ]]
gateway_ip=$(docker inspect -f '{{(index .NetworkSettings.Networks "btcpay_regtest_edge").IPAddress}}' napay-gateway)
[[ $gateway_ip == 10.252.0.* ]]
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
probe() {
    local network=$1; shift
    docker run --rm --user "$(id -u):$(id -g)" --cap-drop ALL --security-opt no-new-privileges:true \
        --network "$network" -v "$ca:/ca.crt:ro" --entrypoint curl "$client" \
        --http1.1 -sS --max-time 10 "$@"
}
pass 'Local internal networks and gateway identity verified'
probe napay-browser-local_egress --cacert /ca.crt -x http://egress:3128 \
    https://btcpay.local/api/v1/health | grep -q '"synchronized":true'
pass 'Napay network reaches synchronized BTCPay through proxy and verified TLS'
if probe napay-browser-local_egress -x http://egress:3128 \
    https://btcpay.local/api/v1/health >/dev/null 2>&1; then
    echo 'FAIL: TLS accepted without local CA.' >&2; exit 1
else
    [[ $? == 60 ]]
fi
pass 'Missing CA rejected with curl60 (TLS verification active)'
for site in napay.local wallet.local pos.localhost btcpay.local; do
    if probe btcpay_regtest_edge --cacert /ca.crt --resolve "$site:443:$gateway_ip" \
        "https://$site/" -o /dev/null 2>/dev/null; then
        echo "FAIL: backend reached $site." >&2; exit 1
    else
        code=$?
        [[ $code == 52 || $code == 56 ]]
    fi
    pass "Backend subnet aborted on $site"
done
printf 'PASS %s local BTCPay transport checks\n' "$checks"
