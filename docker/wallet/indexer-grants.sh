#!/usr/bin/env bash
# SQL dell'utente DB dell'indicizzatore wallet (SIP-029/032), su stdout: la password non finisce negli argomenti
# dei processi. Uso: indexer-grants.sh <database> <file password>  |  mysql -uroot (dentro mysql-main)
set -euo pipefail
db_name=${1:-}
password_file=${2:-}
[[ "$db_name" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Nome database non valido.' >&2; exit 1; }
[[ -f "$password_file" && ! -L "$password_file" ]] || { echo "File password dell'indicizzatore mancante." >&2; exit 1; }
password="$(tr -d '\n' < "$password_file")"
[[ "$password" =~ ^[0-9a-f]{48}$ ]] || { echo "Password dell'indicizzatore non valida (48 caratteri esadecimali)." >&2; exit 1; }
printf "CREATE USER IF NOT EXISTS 'wallet_indexer'@'%%' IDENTIFIED BY '%s';\n" "$password"
printf "ALTER USER 'wallet_indexer'@'%%' IDENTIFIED BY '%s';\n" "$password"
# token dalle variabili d'ambiente (SIP-032): l'indicizzatore legge solo i wallet degli utenti
printf "REVOKE IF EXISTS SELECT ON \`%s\`.\`%s\` FROM 'wallet_indexer'@'%%' IGNORE UNKNOWN USER;\n" "$db_name" nodes "$db_name" smart_contract "$db_name" blockchains
printf "GRANT SELECT ON \`%s\`.\`mp_wallets\` TO 'wallet_indexer'@'%%';\n" "$db_name"
for table in transactions chain_index_cursors; do printf "GRANT SELECT, INSERT, UPDATE ON \`%s\`.\`%s\` TO 'wallet_indexer'@'%%';\n" "$db_name" "$table"; done
for table in mp_notifications mp_notifications_readers; do printf "GRANT SELECT, INSERT ON \`%s\`.\`%s\` TO 'wallet_indexer'@'%%';\n" "$db_name" "$table"; done
