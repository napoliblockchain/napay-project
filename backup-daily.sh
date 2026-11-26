#!/usr/bin/env bash
# SIP-036 parte C: backup giornaliero dei database della VPS A sul suo filesystem (primo livello; la copia fuori
# macchina, es. storage Contabo, la preleva un'altra macchina da NAPAY_BACKUP_DIR). Lanciato dal timer systemd
# docker/systemd/napay-backup.timer. Uso: bash backup-daily.sh /percorso/privato/napay.env
#   - Napay: napay/docker/backup.sh (stesso dump del rilascio);
#   - wallet: database di mysql-main (credenziali solo dentro il container), wallet-<data>-daily.sql.gz.
# Rotazione con NAPAY_BACKUP_KEEP_DAYS (default 14), solo sui file giornalieri. Errore = uscita non zero (systemd lo segnala).
set -euo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
fail() { printf 'ERRORE: %s\n' "$1" >&2; exit 1; }
[[ $# -eq 1 ]] || fail 'uso: backup-daily.sh napay-env-file'
bash "$ROOT/napay/docker/backup.sh" "$1"
backup_dir=$(sed -n 's/^NAPAY_BACKUP_DIR=//p' "$1" | tail -n 1 | sed "s/^\"\(.*\)\"$/\1/; s/^'\(.*\)'$/\1/")
keep=$(sed -n 's/^NAPAY_BACKUP_KEEP_DAYS=//p' "$1" | tail -n 1); keep=${keep:-14}
container=${WALLET_DB_CONTAINER:-mysql-main}
[[ $(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null) == true ]] || fail 'database del wallet non in esecuzione.'
final="$backup_dir/wallet-$(date -u +%Y%m%dT%H%M%SZ)-daily.sql.gz"
partial="$final.partial"
trap 'rm -f "$partial"' EXIT
(set -o noclobber; docker exec "$container" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --quick --routines --triggers --hex-blob --no-tablespaces --set-gtid-purged=OFF "$MYSQL_DATABASE"' \
    | gzip -9 > "$partial") || fail 'backup del database del wallet non riuscito.'
gzip -t "$partial" && [[ $(gzip -dc "$partial" | head -c 4096 | wc -c) -gt 0 ]] || fail 'backup del wallet vuoto o danneggiato.'
chmod 600 "$partial"
mv -n "$partial" "$final"
[[ -f $final ]] || fail 'backup del wallet non salvato.'
find "$backup_dir" -maxdepth 1 -type f -name 'wallet-*-daily.sql.gz' -mtime +"$keep" -delete
echo "Backup wallet: $final"
