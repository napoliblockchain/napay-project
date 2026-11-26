#!/usr/bin/env bash
# Disposable encrypted-set integrity and retry tests; no network or database.
set -euo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
script="$root/docker/backup-offsite/seal-set.sh"
work=$(mktemp -d)
cleanup() { gpgconf --homedir "$work/keys" --kill all >/dev/null 2>&1 || true; rm -rf -- "$work"; }
trap cleanup EXIT
mkdir "$work/keys" "$work/queue" "$work/other"
gpg_cmd=(gpg --no-options --homedir "$work/keys" --batch --no-tty --pinentry-mode loopback --passphrase '')
"${gpg_cmd[@]}" --quick-generate-key 'Backup set fixture <fixture@example.invalid>' rsa2048 encr 0 >/dev/null 2>&1
fingerprint=$("${gpg_cmd[@]}" --with-colons --list-keys 2>/dev/null | awk -F: '$1=="fpr" { print $10; exit }')
"${gpg_cmd[@]}" --export "$fingerprint" > "$work/public.gpg"
printf 'napay fixture\n' | gzip > "$work/napay.sql.gz"
printf 'wallet fixture\n' | gzip > "$work/wallet.sql.gz"
original=$(sha256sum "$work/napay.sql.gz" "$work/wallet.sql.gz")
seal() { bash "$script" "$work/public.gpg" "$fingerprint" "$work/queue" "$work/napay.sql.gz" "$work/wallet.sql.gz"; }
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
reject() { local label=$1; shift; if "$@" > "$work/log" 2>&1; then fail "$label"; fi; pass "$label"; }
seal > "$work/log"
set_dir=$(find "$work/queue" -mindepth 1 -maxdepth 1 -name 'set-*' -type d)
[[ -n $set_dir && $(wc -l < "$set_dir/manifest.sha256") == 2 ]] || fail 'two-file manifest'
bash "$script" --verify "$set_dir" >/dev/null
pass 'complete encrypted pair and checksum manifest published together'
before=$(sha256sum "$set_dir"/*)
seal >/dev/null
[[ $(sha256sum "$set_dir"/*) == "$before" ]] || fail 'retry regenerated ciphertext'
pass 'retry reuses identical encrypted files and manifest'
bash "$script" "$work/public.gpg" "$fingerprint" "$work/queue" "$work/wallet.sql.gz" "$work/napay.sql.gz" >/dev/null
[[ $(sha256sum "$set_dir"/*) == "$before" && $(find "$work/queue" -maxdepth 1 -name 'set-*' | wc -l) == 1 ]] || fail 'source order changed identity'
pass 'source argument order does not duplicate a backup set'
"${gpg_cmd[@]}" --decrypt "$set_dir/napay.sql.gz.gpg" > "$work/recovered.gz" 2>/dev/null
cmp "$work/recovered.gz" "$work/napay.sql.gz" || fail 'recovery'
pass 'sealed source is recoverable byte for byte'
cp "$set_dir/manifest.sha256" "$work/manifest"
printf '%064d  ../../outside.gpg\n' 0 > "$set_dir/manifest.sha256"
reject 'manifest traversal rejected' bash "$script" --verify "$set_dir"
cp "$work/manifest" "$set_dir/manifest.sha256"
cp "$set_dir/napay.sql.gz.gpg" "$work/cipher"
printf 'damage' >> "$set_dir/napay.sql.gz.gpg"
reject 'ciphertext integrity mismatch rejected' bash "$script" --verify "$set_dir"
reject 'corrupt existing set is not overwritten by retry' seal
cp "$work/cipher" "$set_dir/napay.sql.gz.gpg"
chmod 644 "$set_dir/manifest.sha256"
reject 'public manifest permissions rejected' bash "$script" --verify "$set_dir"
chmod 600 "$set_dir/manifest.sha256"
cp "$work/napay.sql.gz" "$work/other/napay.sql.gz"
reject 'duplicate source basenames rejected' bash "$script" "$work/public.gpg" "$fingerprint" "$work/queue" "$work/napay.sql.gz" "$work/other/napay.sql.gz"
rm "$set_dir/napay.sql.gz.gpg"; ln -s "$work/cipher" "$set_dir/napay.sql.gz.gpg"
reject 'symlink ciphertext rejected' bash "$script" --verify "$set_dir"
rm "$set_dir/napay.sql.gz.gpg"; cp "$work/cipher" "$set_dir/napay.sql.gz.gpg"
[[ $(sha256sum "$work/napay.sql.gz" "$work/wallet.sql.gz") == "$original" ]] || fail 'original data changed'
[[ -z $(find "$work/queue" -maxdepth 1 -name '.sealing.*' -print -quit) ]] || fail 'temporary directory left'
pass 'original backups preserved and staging directories cleaned'
mkdir "$work/failed" "$work/concurrent"
printf 'not a recipient key\n' > "$work/bad-key.gpg"
reject 'encryption failure does not publish an incomplete set' bash "$script" "$work/bad-key.gpg" "$fingerprint" "$work/failed" "$work/napay.sql.gz"
[[ -z $(find "$work/failed" -mindepth 1 -print -quit) ]] || fail 'failed set left partial artifacts'
concurrent() { bash "$script" "$work/public.gpg" "$fingerprint" "$work/concurrent" "$work/napay.sql.gz" "$work/wallet.sql.gz"; }
concurrent > "$work/first.log" 2>&1 & first=$!
concurrent > "$work/second.log" 2>&1 & second=$!
wait "$first"; wait "$second"
concurrent_set=$(find "$work/concurrent" -mindepth 1 -maxdepth 1 -name 'set-*' -type d)
[[ $(find "$work/concurrent" -mindepth 1 -maxdepth 1 | wc -l) == 1 ]] || fail 'concurrent publication left extra sets'
bash "$script" --verify "$concurrent_set" >/dev/null
pass 'concurrent sealing publishes one complete set and cleans losing staging'
