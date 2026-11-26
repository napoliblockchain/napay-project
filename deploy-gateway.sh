#!/usr/bin/env bash
# SIP-036 parte C: gateway di produzione (VPS A), unico ingresso pubblico su 80/443 con Let's Encrypt.
# Uso: bash deploy-gateway.sh /percorso/privato/gateway.env [--check]
#   --check  valida file env, variabili, modello compose e Caddyfile (caddy validate, senza rete) senza creare o avviare.
# Variabili (file 0600 fuori dai repository, letto senza eseguirlo):
#   GATEWAY_ACME_EMAIL, NAPAY_DOMAIN, POS_DOMAIN, WALLET_DOMAIN,
#   NAPAY_GATEWAY_NETWORK + NAPAY_GATEWAY_SUBNET  (rete interna gateway <-> napay; la subnet va in NAPAY_TRUSTED_PROXIES di napay)
#   POS_GATEWAY_NETWORK + POS_GATEWAY_SUBNET      (rete interna gateway <-> POS; unica origine di /api/pos/*)
#   BTCPAY_SOURCE_IPS                             (IP pubblici del server BTCPay, separati da spazi: unica origine dei webhook)
# Le reti si creano solo se assenti; se esistono devono essere interne e con la stessa subnet. Ordine di rilascio:
# questo script, poi napay (docker/deploy.sh), POS e wallet.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
CADDY_IMAGE=caddy:2.8.4-alpine
fail() { printf 'ERRORE: %s\n' "$1" >&2; exit 1; }

[[ $# -ge 1 && $# -le 2 && ( ${2:-} == '' || ${2:-} == --check ) ]] || fail 'uso: deploy-gateway.sh env-file [--check]'
[[ -f "$1" && ! -L "$1" ]] || fail 'file env mancante o collegamento simbolico.'
ENV_FILE="$(cd -- "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
case "$ENV_FILE" in "$ROOT"/*) fail 'il file env deve stare fuori dai repository.' ;; esac
[[ "$(stat -c '%u' "$ENV_FILE")" == "$(id -u)" ]] || fail 'il file env deve appartenere a chi lancia il deploy.'
(( (8#$(stat -c '%a' "$ENV_FILE") & 077) == 0 )) || fail 'il file env deve essere leggibile solo dal proprietario (chmod 600).'
env_value() { sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | sed "s/^\"\(.*\)\"$/\1/; s/^'\(.*\)'$/\1/"; }

host='([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}'
ipv4='(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})){3}'
[[ "$(env_value GATEWAY_ACME_EMAIL)" =~ ^[A-Za-z0-9._%+-]+@$host$ ]] || fail 'GATEWAY_ACME_EMAIL mancante o non valida.'
for name in NAPAY_DOMAIN POS_DOMAIN WALLET_DOMAIN; do
    value=$(env_value "$name")
    [[ $value =~ ^$host$ && $value != *.local && $value != *.test && $value != localhost ]] || fail "$name mancante o non pubblico."
done
[[ "$(printf '%s\n' "$(env_value NAPAY_DOMAIN)" "$(env_value POS_DOMAIN)" "$(env_value WALLET_DOMAIN)" | sort -u | wc -l)" == 3 ]] || fail 'i tre domini devono essere distinti.'
for net in NAPAY POS; do
    [[ "$(env_value ${net}_GATEWAY_NETWORK)" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$ ]] || fail "${net}_GATEWAY_NETWORK mancante o non valida."
    [[ "$(env_value ${net}_GATEWAY_SUBNET)" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)[0-9.]+/(1[6-9]|2[0-9])$ && "$(env_value ${net}_GATEWAY_SUBNET)" =~ ^$ipv4/ ]] \
        || fail "${net}_GATEWAY_SUBNET mancante o non privata (/16-/29)."
done
[[ "$(env_value NAPAY_GATEWAY_NETWORK)" != "$(env_value POS_GATEWAY_NETWORK)" && "$(env_value NAPAY_GATEWAY_SUBNET)" != "$(env_value POS_GATEWAY_SUBNET)" ]] \
    || fail 'reti napay e POS devono essere distinte.'
[[ "$(env_value BTCPAY_SOURCE_IPS)" =~ ^$ipv4(\ $ipv4)*$ ]] || fail 'BTCPAY_SOURCE_IPS mancante o non valida (IPv4 separati da spazi).'

compose=(docker compose --project-directory "$ROOT" --env-file "$ENV_FILE" -f "$ROOT/docker-compose.yml" -f "$ROOT/docker-compose.prod.yml")
"${compose[@]}" config --quiet || fail 'configurazione docker compose non valida.'
# Caddyfile con i valori reali, senza rete né certificati: solo sintassi e moduli
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
for name in GATEWAY_ACME_EMAIL NAPAY_DOMAIN POS_DOMAIN WALLET_DOMAIN POS_GATEWAY_SUBNET BTCPAY_SOURCE_IPS; do
    printf '%s=%s\n' "$name" "$(env_value "$name")" >> "$work/caddy.env"
done
docker run --rm --network none --read-only --tmpfs /tmp --tmpfs /data --tmpfs /config --env-file "$work/caddy.env" \
    -v "$ROOT/docker/gateway/prod/Caddyfile:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || fail 'Caddyfile di produzione non valido.'

if [[ ${2:-} == --check ]]; then echo 'Gateway preflight OK; nothing created or started.'; exit 0; fi

for net in NAPAY POS; do
    name=$(env_value ${net}_GATEWAY_NETWORK); subnet=$(env_value ${net}_GATEWAY_SUBNET)
    if docker network inspect "$name" >/dev/null 2>&1; then
        [[ "$(docker network inspect --format '{{.Internal}} {{range .IPAM.Config}}{{.Subnet}}{{end}}' "$name")" == "true $subnet" ]] \
            || fail "rete $name esistente ma non interna o con subnet diversa."
    else
        docker network create --internal --subnet "$subnet" --label napay.service=gateway "$name" >/dev/null
    fi
done
"${compose[@]}" up -d --no-deps gateway
echo 'Gateway avviato: certificati Let'"'"'s Encrypt al primo accesso ai domini (DNS già puntati su questa VPS).'
