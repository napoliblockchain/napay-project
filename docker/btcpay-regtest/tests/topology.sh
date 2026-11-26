#!/usr/bin/env bash
# SIP-022 B0-RV3/RV4: topologia proposta con controfigure locali, senza Internet ne host reali.
#   backend (BTCPay)  -- edge (interna, subnet fissa) --  gateway  -- client (interna) --  egress  -- napay (interna) -- web
#                                                                                         egress  -- sim (interna) -- sentinella "api-m.paypal.com"
# Ogni controllo negativo ha un controllo positivo che dimostra che il percorso esiste dove deve esistere.
set -euo pipefail
umask 077
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
for tool in docker openssl od; do command -v "$tool" >/dev/null || { echo "FAIL: missing prerequisite $tool" >&2; exit 1; }; done
run=$(openssl rand -hex 4)
p=btcpay-topo-$run
edge_subnet="10.253.$(( $(od -An -N1 -tu1 /dev/urandom) % 200 + 20 )).0/24"
caddy=caddy:2.8.4-alpine@sha256:af32e97399febea808609119bb21544d0265c58a02836576e32a2d082c262c17
client_image=$(sed -n 's/^ *image: \(nicolasdorier\/nbxplorer:.*\)$/\1/p' "$dir/../compose.yml")
egress_image=btcpay-regtest-test-egress:$run
work=$(mktemp -d)
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
cleanup() {
    code=$?
    trap - EXIT
    docker rm -f "$p-backend" "$p-gateway" "$p-egress" "$p-sentinel" >/dev/null 2>&1 || true
    for net in edge client napay sim; do docker network rm "$p-$net" >/dev/null 2>&1 || true; done
    docker image rm "$egress_image" >/dev/null 2>&1 || true
    rm -rf -- "$work"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
# probe NETWORK curl-args... -> imposta $out e $code (exit di curl)
probe() {
    local net=$1; shift
    set +e
    out=$(docker run --rm --network "$net" -v "$work/ca.crt:/ca.crt:ro" --entrypoint curl "$client_image" -sS --max-time 5 "$@" 2>&1)
    code=$?
    set -e
}
ip_on() { docker inspect -f "{{(index .NetworkSettings.Networks \"$2\").IPAddress}}" "$1"; }
# insieme di reti in ordine byte (LC_ALL=C), indipendente dalla lingua di sistema
networks_of() { docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$1" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' '; }
expect_networks() { printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' ' '; }

# prerequisiti: client con curl, ricetta proxy
docker run --rm --network none --entrypoint curl "$client_image" --version >/dev/null
docker build -q -t "$egress_image" "$dir/fixtures/egress" >/dev/null
docker network create --internal --subnet "$edge_subnet" "$p-edge" >/dev/null
for net in client napay sim; do docker network create --internal "$p-$net" >/dev/null; done
docker run -d --name "$p-backend" --network "$p-edge" --network-alias btcpay-regtest "$caddy" caddy respond --listen :49392 btcpay-backend >/dev/null
docker run -d --name "$p-sentinel" --network "$p-sim" --network-alias api-m.paypal.com --network-alias evil.example "$caddy" caddy respond --listen :443 sentinel >/dev/null
docker create --name "$p-gateway" --network "$p-edge" -e EDGE_SUBNET="$edge_subnet" \
    -v "$dir/fixtures/gateway/Caddyfile:/etc/caddy/Caddyfile:ro" "$caddy" >/dev/null
docker network connect --alias btcpay.local "$p-client" "$p-gateway"
docker start "$p-gateway" >/dev/null
docker create --name "$p-egress" --network "$p-napay" --network-alias egress --read-only --tmpfs /tmp --cap-drop ALL "$egress_image" >/dev/null
docker network connect "$p-client" "$p-egress"
docker network connect "$p-sim" "$p-egress"
docker start "$p-egress" >/dev/null
for _ in $(seq 1 30); do docker exec "$p-gateway" test -f /data/caddy/pki/authorities/local/root.crt 2>/dev/null && break; sleep 1; done
docker cp "$p-gateway:/data/caddy/pki/authorities/local/root.crt" "$work/ca.crt" >/dev/null
chmod 644 "$work/ca.crt"
sleep 2

[[ $(networks_of "$p-backend") == "$(expect_networks "$p-edge")" && $(networks_of "$p-gateway") == "$(expect_networks "$p-client" "$p-edge")" ]]
[[ $(networks_of "$p-egress") == "$(expect_networks "$p-client" "$p-napay" "$p-sim")" ]]
pass 'Backend only on edge; gateway on edge+client; egress on client, never on edge'

# percorso previsto: web -> proxy -> btcpay.local (TLS verificato) -> backend
probe "$p-napay" --cacert /ca.crt -x http://egress:3128 https://btcpay.local/
[[ $code == 0 && $out == btcpay-backend ]]
pass 'Web reaches BTCPay only via proxy and gateway, TLS verified with local CA'
probe "$p-napay" -x http://egress:3128 https://btcpay.local/
[[ $code == 60 ]]
pass 'Without the local CA the certificate is rejected (verification active)'
probe "$p-napay" -v -x http://egress:3128 https://api-m.paypal.com/
grep -q '200 Connection established' <<<"$out"
pass 'Positive control: allowed payment host tunnels through the proxy (sentinel only)'
probe "$p-napay" -v -x http://egress:3128 https://evil.example/
grep -q 'CONNECT tunnel failed, response 403' <<<"$out"
pass 'Host outside the allowlist refused by the proxy (403)'
probe "$p-napay" -v -x http://egress:3128 https://btcpay.local:8443/
grep -q 'CONNECT tunnel failed, response 403' <<<"$out"
probe "$p-napay" -o /dev/null -w '%{http_code}' -x http://egress:3128 http://btcpay.local/
[[ $out == 403 ]]
pass 'btcpay.local only on 443 via CONNECT (other port and plain HTTP refused)'
probe "$p-napay" http://btcpay-regtest:49392/
[[ $code == 6 || $code == 7 || $code == 28 ]]
probe "$p-napay" "http://$(ip_on "$p-backend" "$p-edge"):49392/"
[[ $code == 7 || $code == 28 ]]
pass 'Web has no direct path to the BTCPay backend (name or IP)'

# B0-RV3: il backend non raggiunge il proxy di uscita su nessuno dei suoi indirizzi
for name in egress "$p-egress"; do
    probe "$p-edge" -x "http://$name:3128" https://api-m.paypal.com/
    [[ $code == 5 ]]
done
# tutti gli indirizzi effettivi del proxy, su qualunque rete sia collegato
for net in $(networks_of "$p-egress"); do
    probe "$p-edge" -o /dev/null -w '%{http_code}' -x "http://$(ip_on "$p-egress" "$net"):3128" https://api-m.paypal.com/
    [[ ($code == 7 || $code == 28) && $out != *200* ]]
done
pass 'Backend cannot reach the egress proxy (no name, every proxy IP unreachable)'
probe "$p-edge" "https://$(ip_on "$p-sentinel" "$p-sim"):443/" -k
[[ $code == 7 || $code == 28 ]]
pass 'Backend cannot reach the simulated Internet directly'

# lateralita: il backend arriva al gateway ma il gateway lo rifiuta su ogni sito
gateway_edge=$(ip_on "$p-gateway" "$p-edge")
gateway_client=$(ip_on "$p-gateway" "$p-client")
probe "$p-client" --cacert /ca.crt --resolve "napay.local:443:$gateway_client" https://napay.local/
[[ $code == 0 && $out == napay-site ]]
probe "$p-client" --cacert /ca.crt --resolve "wallet.local:443:$gateway_client" https://wallet.local/ws-notify
[[ $code == 0 && $out == wallet-ws ]]
pass 'Positive control: other gateway sites answer on the client network'
for target in napay.local/ btcpay.local/ wallet.local/ wallet.local/ws-notify; do
    probe "$p-edge" --cacert /ca.crt --resolve "${target%%/*}:443:$gateway_edge" "https://$target"
    [[ $code != 0 && $out != *-site* && $out != *btcpay-backend* && $out != *wallet-ws* ]]
done
pass 'Requests from the backend subnet aborted by the gateway on every site'
printf 'PASS %d B0 topology checks (local sentinels only)\n' "$checks"
