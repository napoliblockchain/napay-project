#!/usr/bin/env bash
# SIP-036 parte C: gateway di produzione. (1) deploy-gateway.sh --check: rifiuti senza creare o avviare nulla.
# (2) Comportamento della Caddyfile di produzione su reti usa-e-getta, con servizi finti al posto delle app e
#     certificati locali al posto di Let's Encrypt (unica differenza): instradamento per dominio, /api/pos solo dalla
#     rete dei POS, webhook BTCPay solo dall'IP del server BTCPay, intestazioni di sicurezza. Nessuna porta sull'host.
set -euo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
caddy=caddy:2.8.4-alpine
client=${GATEWAY_TEST_CLIENT_IMAGE:-napay/napay:dev}
run=$(openssl rand -hex 4)
work=$(mktemp -d)
nets=(public napay pos wallet)
containers=(gw napay-web pos-web wallet-web cli-public cli-btcpay cli-pos)
cleanup() {
    code=$?; trap - EXIT
    for c in "${containers[@]}"; do docker rm -f "gwtest-$run-$c" >/dev/null 2>&1 || true; done
    for n in "${nets[@]}"; do docker network rm "gwtest-$run-$n" >/dev/null 2>&1 || true; done
    rm -rf "$work"; exit "$code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# --- 1. preflight
cat > "$work/base.env" <<'ENV'
GATEWAY_ACME_EMAIL=ops@napoliblockchain.it
NAPAY_DOMAIN=napay.napoliblockchain.it
POS_DOMAIN=pos.napoliblockchain.it
WALLET_DOMAIN=wallet.napoliblockchain.it
NAPAY_GATEWAY_NETWORK=napay_gateway_never_created
NAPAY_GATEWAY_SUBNET=10.250.10.0/24
POS_GATEWAY_NETWORK=pos_gateway_never_created
POS_GATEWAY_SUBNET=10.250.11.0/24
BTCPAY_SOURCE_IPS=213.136.89.96
ENV
chmod 600 "$work/base.env"
preflight() { bash "$root/deploy-gateway.sh" "${1:-$work/test.env}" --check > "$work/out" 2>&1; }
change() { sed "s|^$1=.*|$1=$2|" "$work/base.env" > "$work/test.env"; chmod 600 "$work/test.env"; }
cp "$work/base.env" "$work/test.env"; chmod 600 "$work/test.env"
preflight && grep -q 'Gateway preflight OK' "$work/out" || fail 'valid preflight'
docker network inspect napay_gateway_never_created >/dev/null 2>&1 && fail 'preflight created a network'
pass 'Valid production gateway configuration: compose and Caddyfile validated, nothing created'
reject() { if preflight; then fail "$1"; fi; pass "$1"; }
change NAPAY_DOMAIN napay.local; reject 'Local domain refused'
change POS_DOMAIN napay.napoliblockchain.it; reject 'Duplicate domains refused'
change GATEWAY_ACME_EMAIL nobody; reject 'Invalid ACME contact refused'
change NAPAY_GATEWAY_SUBNET 8.8.8.0/24; reject 'Public subnet refused'
change POS_GATEWAY_SUBNET 10.250.10.0/24; reject 'Same subnet for napay and POS refused'
change BTCPAY_SOURCE_IPS 'any'; reject 'Invalid BTCPay source IPs refused'
cp "$work/base.env" "$work/test.env"; chmod 644 "$work/test.env"; reject 'Readable-by-others env refused'
cp "$work/base.env" "$root/gateway-test.env" 2>/dev/null && { chmod 600 "$root/gateway-test.env"; if preflight "$root/gateway-test.env"; then rm -f "$root/gateway-test.env"; fail 'env in repository'; fi; rm -f "$root/gateway-test.env"; pass 'Env inside the repository refused'; }

# --- 2. comportamento della Caddyfile di produzione
oct=$(( $(od -An -N1 -tu1 /dev/urandom) % 150 + 50 ))
declare -A subnet=([public]="10.248.$oct.0/24" [napay]="10.248.$((oct + 1)).0/24" [pos]="10.248.$((oct + 2)).0/24" [wallet]="10.248.$((oct + 3)).0/24")
for n in "${nets[@]}"; do docker network create --internal --subnet "${subnet[$n]}" "gwtest-$run-$n" >/dev/null; done
pub=${subnet[public]%.0/24}
stub() { # stub NOME RETE ALIAS TESTO
    docker run -d --name "gwtest-$run-$1" --network "gwtest-$run-$2" --network-alias "$3" "$caddy" caddy respond --listen :80 --body "$4" >/dev/null
}
stub napay-web napay napay-web 'napay-web'
stub pos-web pos pos-v2-web 'pos-web'
stub wallet-web wallet wallet-web 'wallet-web'
# Caddyfile di produzione identica, tranne la CA: certificati locali invece di Let's Encrypt
sed 's/^    email {\$GATEWAY_ACME_EMAIL}$/    local_certs/' "$root/docker/gateway/prod/Caddyfile" > "$work/Caddyfile"
grep -q '^    local_certs$' "$work/Caddyfile" || fail 'test Caddyfile substitution'
docker create --name "gwtest-$run-gw" --network "gwtest-$run-public" --ip "$pub.10" \
    -e NAPAY_DOMAIN=napay.napoliblockchain.it -e POS_DOMAIN=pos.napoliblockchain.it -e WALLET_DOMAIN=wallet.napoliblockchain.it \
    -e POS_GATEWAY_SUBNET="${subnet[pos]}" -e BTCPAY_SOURCE_IPS="$pub.20" -e GATEWAY_ACME_EMAIL=ops@napoliblockchain.it \
    -v "$work/Caddyfile:/etc/caddy/Caddyfile:ro" "$caddy" >/dev/null
docker network connect "gwtest-$run-napay" "gwtest-$run-gw"
docker network connect --ip "${subnet[pos]%.0/24}.10" "gwtest-$run-pos" "gwtest-$run-gw"
docker network connect "gwtest-$run-wallet" "gwtest-$run-gw"
docker start "gwtest-$run-gw" >/dev/null
client() { # client NOME RETE IP
    docker run -d --name "gwtest-$run-$1" --network "gwtest-$run-$2" --ip "$3" --entrypoint sleep "$client" 600 >/dev/null
}
client cli-public public "$pub.30"
client cli-btcpay public "$pub.20"
client cli-pos pos "${subnet[pos]%.0/24}.30"
call() { # call CLIENT GATEWAY_IP HOST PATH -> "codice corpo"
    docker exec "gwtest-$run-$1" curl -sk --max-time 10 --resolve "$3:443:$2" -o /tmp/body -w '%{http_code}' "https://$3$4" 2>/dev/null; printf ' '
    docker exec "gwtest-$run-$1" cat /tmp/body 2>/dev/null || true
}
for _ in $(seq 1 30); do [[ $(call cli-public "$pub.10" napay.napoliblockchain.it /) == '200 napay-web' ]] && break; sleep 1; done
gw_pos="${subnet[pos]%.0/24}.10"
[[ $(call cli-public "$pub.10" napay.napoliblockchain.it /site/login) == '200 napay-web' ]] || fail 'napay domain'
[[ $(call cli-public "$pub.10" pos.napoliblockchain.it /) == '200 pos-web' ]] || fail 'POS domain'
[[ $(call cli-public "$pub.10" wallet.napoliblockchain.it /) == '200 wallet-web' ]] || fail 'wallet domain'
pass 'Each public domain reaches only its own application'
[[ $(call cli-public "$pub.10" napay.napoliblockchain.it /api/pos/v1/sessions | cut -d' ' -f1) == 404 ]] || fail 'POS API from internet'
[[ $(call cli-pos "$gw_pos" napay.napoliblockchain.it /api/pos/v1/sessions) == '200 napay-web' ]] || fail 'POS API from POS network'
pass 'POS API refused from the internet, proxied only from the POS network'
[[ $(call cli-public "$pub.10" napay.napoliblockchain.it /api/btcpay/v1/store-webhook | cut -d' ' -f1) == 404 ]] || fail 'BTCPay webhook from other IP'
[[ $(call cli-btcpay "$pub.10" napay.napoliblockchain.it /api/btcpay/v1/store-webhook) == '200 napay-web' ]] || fail 'BTCPay webhook from BTCPay IP'
[[ $(call cli-btcpay "$pub.10" napay.napoliblockchain.it /api/btcpay/v1/webhook) == '200 napay-web' ]] || fail 'membership webhook from BTCPay IP'
pass 'BTCPay webhooks accepted only from the BTCPay server IP'
headers=$(docker exec "gwtest-$run-cli-public" curl -skI --max-time 10 --resolve "napay.napoliblockchain.it:443:$pub.10" https://napay.napoliblockchain.it/)
grep -qi '^strict-transport-security: max-age=31536000' <<< "$headers" && grep -qi '^x-content-type-options: nosniff' <<< "$headers" \
    && ! grep -qi '^server:' <<< "$headers" || fail 'security headers'
pos_headers=$(docker exec "gwtest-$run-cli-public" curl -skI --max-time 10 --resolve "pos.napoliblockchain.it:443:$pub.10" https://pos.napoliblockchain.it/)
grep -qi '^x-frame-options: DENY' <<< "$pos_headers" && grep -qi "^content-security-policy: default-src 'self'" <<< "$pos_headers" || fail 'POS headers'
pass 'HSTS, nosniff and no Server header; POS also frame-deny and CSP'
[[ $(docker exec "gwtest-$run-cli-public" curl -s -o /dev/null -w '%{http_code}' --max-time 10 --resolve "napay.napoliblockchain.it:80:$pub.10" http://napay.napoliblockchain.it/x) =~ ^30[18]$ ]] || fail 'HTTP redirect'
pass 'Plain HTTP redirected to HTTPS'
printf 'PASS %s production gateway checks\n' "$checks"
