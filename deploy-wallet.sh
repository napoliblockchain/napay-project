#!/usr/bin/env bash
# Deploy del wallet v2 (immagine prod): controlli, build, migration automatiche, wallet-web, indicizzatore.
# Uso: bash deploy-wallet.sh /percorso/privato/napay.env [--check]
#   --check  valida file env, segreti e compose senza costruire né avviare nulla.
# Il file env (0600, fuori dai repository) contiene i valori della piattaforma (MYSQL_*, APP_ENV, ...) e del wallet:
#   WALLET_CHAIN_RPC_URL, WALLET_CHAIN_ID, WALLET_CHAIN_NAME, WALLET_CHAIN_SYMBOL, WALLET_CHAIN_ZERO_GAS,
#   WALLET_CHAIN_EXPLORER_URL, WALLET_TTS_TOKEN_ADDRESS, WALLET_TTS_TOKEN_NAME/SYMBOL/DECIMALS,
#   WALLET_INDEXER_SECRET_FILE, WALLET_REALTIME_KEY_FILE.
# Se la migration fallisce il deploy si ferma e wallet-web resta alla versione precedente.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
fail() { printf 'ERRORE: %s\n' "$1" >&2; exit 1; }

[[ $# -ge 1 && $# -le 2 && ( ${2:-} == '' || ${2:-} == --check ) ]] || fail 'uso: deploy-wallet.sh env-file [--check]'
[[ -f "$1" && ! -L "$1" ]] || fail 'file env mancante o collegamento simbolico.'
ENV_FILE="$(cd -- "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
case "$ENV_FILE" in "$ROOT"/*) fail 'il file env deve stare fuori dai repository.' ;; esac
[[ "$(stat -c '%u' "$ENV_FILE")" == "$(id -u)" ]] || fail 'il file env deve appartenere a chi lancia il deploy.'
(( (8#$(stat -c '%a' "$ENV_FILE") & 077) == 0 )) || fail 'il file env deve essere leggibile solo dal proprietario (chmod 600).'

# valori letti senza eseguire il file (nessun source)
env_value() { sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
private_file() {
  local path=$1 label=$2
  [[ -n "$path" && -f "$path" && ! -L "$path" ]] || fail "$label mancante."
  case "$(cd -- "$(dirname -- "$path")" && pwd -P)/" in "$ROOT"/*) fail "$label deve stare fuori dai repository." ;; esac
  (( (8#$(stat -c '%a' "$(dirname -- "$path")") & 077) == 0 )) || fail "la cartella di $label deve essere privata (chmod 700)."
}

db_name="$(env_value MYSQL_DATABASE)"
[[ "$db_name" =~ ^[A-Za-z0-9_]+$ ]] || fail 'MYSQL_DATABASE mancante o non valido.'
[[ -n "$(env_value MYSQL_USER)" && -n "$(env_value MYSQL_PASSWORD)" ]] || fail 'MYSQL_USER o MYSQL_PASSWORD mancanti.'
[[ "$(env_value WALLET_CHAIN_RPC_URL)" =~ ^https?://[^[:space:]]+$ ]] || fail 'WALLET_CHAIN_RPC_URL mancante o non valido.'
[[ "$(env_value WALLET_CHAIN_ID)" =~ ^[1-9][0-9]{0,9}$ ]] || fail 'WALLET_CHAIN_ID mancante o non valido.'
[[ "$(env_value WALLET_TTS_TOKEN_ADDRESS)" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail 'WALLET_TTS_TOKEN_ADDRESS mancante o non valido.'
explorer="$(env_value WALLET_CHAIN_EXPLORER_URL)"
[[ -z "$explorer" || "$explorer" =~ ^https?://[^[:space:]]+$ ]] || fail 'WALLET_CHAIN_EXPLORER_URL non valido.'
indexer_secret="$(env_value WALLET_INDEXER_SECRET_FILE)"
realtime_key="$(env_value WALLET_REALTIME_KEY_FILE)"
private_file "$indexer_secret" "WALLET_INDEXER_SECRET_FILE"
private_file "$realtime_key" "WALLET_REALTIME_KEY_FILE"

# immagini di rilascio: la shell ha la precedenza sul file env nell'interpolazione di compose
export WALLET_BUILD_TARGET=prod WALLET_IMAGE_TAG="${WALLET_IMAGE_TAG:-prod}"
[[ "$WALLET_IMAGE_TAG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ ]] || fail 'WALLET_IMAGE_TAG non valido.'
compose=(docker compose --project-directory "$ROOT" --env-file "$ENV_FILE" -f "$ROOT/docker-compose.yml" --profile deploy --profile chain)
"${compose[@]}" config --quiet || fail 'configurazione docker compose non valida.'

if [[ ${2:-} == --check ]]; then
  printf 'Controllo deploy wallet OK: nessuna immagine costruita, nessun servizio avviato.\n'
  exit 0
fi

printf '== 1/4 Build immagini (wallet-web prod, indicizzatore)\n'
"${compose[@]}" build wallet-web wallet-realtime

printf '== 2/4 Database e migration\n'
"${compose[@]}" up -d --wait mysql-main redis-main
"${compose[@]}" run --rm wallet-migrate || fail 'migration non applicate: wallet-web lasciato alla versione precedente.'

printf '== 3/4 Wallet\n'
"${compose[@]}" up -d --wait --no-deps wallet-web

printf "== 4/4 Indicizzatore (utente DB a permessi minimi)\n"
bash "$ROOT/docker/wallet/indexer-grants.sh" "$db_name" "$indexer_secret" \
  | docker exec -i mysql-main sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot' \
  || fail "utente DB dell'indicizzatore non aggiornato."
"${compose[@]}" up -d --wait --no-deps wallet-realtime
printf 'Deploy wallet completato (immagine napay/poawallet:%s).\n' "$WALLET_IMAGE_TAG"
