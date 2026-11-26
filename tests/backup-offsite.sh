#!/usr/bin/env bash
# Offline cryptographic tests only; no S3, database, Docker or production keys.
set -euo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
script="$root/docker/backup-offsite/encrypt.sh"
work=$(mktemp -d)
cleanup() {
    gpgconf --homedir "$work/recovery" --kill all >/dev/null 2>&1 || true
    rm -rf -- "$work"
}
trap cleanup EXIT
mkdir "$work/recovery" "$work/out" "$work/input" "$work/public-only"
gpg_cmd=(gpg --no-options --homedir "$work/recovery" --batch --no-tty --pinentry-mode loopback --passphrase '')
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
"${gpg_cmd[@]}" --quick-generate-key 'SIP038 Test <fixture@example.invalid>' rsa2048 encr 0 >/dev/null 2>&1
fingerprint=$("${gpg_cmd[@]}" --with-colons --list-keys 2>/dev/null | awk -F: '$1=="fpr" { print $10; exit }')
"${gpg_cmd[@]}" --export "$fingerprint" > "$work/input/recipient.gpg"
"${gpg_cmd[@]}" --export-secret-keys "$fingerprint" > "$work/input/private.gpg"
printf 'SIP038 fixture: exact restore including binary bytes\000\377\n' | gzip > "$work/input/napay-fixture.sql.gz"
original=$(sha256sum "$work/input/napay-fixture.sql.gz" | cut -d' ' -f1)
run() { bash "$script" "$work/input/recipient.gpg" "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"; }
reject() {
    local label=$1; shift
    if "$@" > "$work/log" 2>&1; then fail "$label"; fi
    [[ ! -e $work/out/napay-fixture.sql.gz.gpg ]] || fail 'failed operation published ciphertext'
    [[ -z $(find "$work/out" -mindepth 1 -maxdepth 1 -print -quit) ]] || fail 'failed operation left temporary files'
    [[ $(sha256sum "$work/input/napay-fixture.sql.gz" | cut -d' ' -f1) == "$original" ]] || fail 'source was modified'
    pass "$label"
}
run >/dev/null
cipher="$work/out/napay-fixture.sql.gz.gpg"
[[ $(stat -c '%a' "$cipher") == 600 ]] || fail 'ciphertext permissions'
"${gpg_cmd[@]}" --decrypt "$cipher" > "$work/restored.gz" 2>/dev/null
cmp "$work/restored.gz" "$work/input/napay-fixture.sql.gz" || fail 'recovery mismatch'
gzip -t "$work/restored.gz"
pass 'asymmetric recovery matches every source byte; ciphertext mode 0600'
gpg --no-options --homedir "$work/public-only" --batch --import "$work/input/recipient.gpg" >/dev/null 2>&1
if gpg --no-options --homedir "$work/public-only" --batch --decrypt "$cipher" > /dev/null 2>&1; then fail 'public-only decryption'; fi
pass 'public encryption key cannot recover the backup'
before=$(sha256sum "$cipher")
if run > "$work/log" 2>&1; then fail 'overwrite accepted'; fi
[[ $(sha256sum "$cipher") == "$before" ]] || fail 'existing ciphertext was changed'
pass 'existing encrypted backup is never overwritten'
cp "$cipher" "$work/tampered.gpg"
size=$(stat -c '%s' "$work/tampered.gpg")
truncate -s "$((size - 16))" "$work/tampered.gpg"
if "${gpg_cmd[@]}" --decrypt "$work/tampered.gpg" > /dev/null 2>&1; then fail 'tampered backup accepted'; fi
pass 'damaged ciphertext fails integrity validation'
rm "$cipher"
reject 'short fingerprint refused' bash "$script" "$work/input/recipient.gpg" ABCD "$work/input/napay-fixture.sql.gz" "$work/out"
reject 'mismatched full fingerprint refused' bash "$script" "$work/input/recipient.gpg" 0000000000000000000000000000000000000000 "$work/input/napay-fixture.sql.gz" "$work/out"
reject 'private recovery key refused' bash "$script" "$work/input/private.gpg" "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"
chmod 644 "$work/input/napay-fixture.sql.gz"
reject 'world-readable backup refused' run
chmod 600 "$work/input/napay-fixture.sql.gz"
chmod 777 "$work/out"
reject 'public output directory refused' run
chmod 700 "$work/out"
ln -s "$work/input/napay-fixture.sql.gz" "$work/input/link.sql.gz"
reject 'symlink input refused' bash "$script" "$work/input/recipient.gpg" "$fingerprint" "$work/input/link.sql.gz" "$work/out"
ln -s "$work/input" "$work/alias"
reject 'symlink ancestor refused' bash "$script" "$work/input/recipient.gpg" "$fingerprint" "$work/alias/napay-fixture.sql.gz" "$work/out"
reject 'relative paths refused' bash "$script" relative-key "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"
touch "$work/input/empty.sql.gz"
reject 'empty backup refused' bash "$script" "$work/input/recipient.gpg" "$fingerprint" "$work/input/empty.sql.gz" "$work/out"
cp "$work/input/napay-fixture.sql.gz" "$work/input/backup.partial"
reject 'incomplete local backup refused' bash "$script" "$work/input/recipient.gpg" "$fingerprint" "$work/input/backup.partial" "$work/out"
printf 'not a public key\n' > "$work/input/invalid.gpg"
reject 'malformed key refused' bash "$script" "$work/input/invalid.gpg" "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"
"${gpg_cmd[@]}" --quick-generate-key 'SIP038 Other <other@example.invalid>' rsa2048 encr 0 >/dev/null 2>&1
"${gpg_cmd[@]}" --export > "$work/input/bundle.gpg"
reject 'multiple primary keys refused' bash "$script" "$work/input/bundle.gpg" "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"
mkdir "$work/bin"
cat > "$work/bin/gpg" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
    [[ $argument != --encrypt ]] || exit 42
done
exec "$NAPAY_TEST_REAL_GPG" "$@"
EOF
chmod 700 "$work/bin/gpg"
reject 'encryption failure leaves no complete or temporary output' env PATH="$work/bin:$PATH" \
    NAPAY_TEST_REAL_GPG="$(command -v gpg)" bash "$script" "$work/input/recipient.gpg" \
    "$fingerprint" "$work/input/napay-fixture.sql.gz" "$work/out"
run > "$work/first.log" 2>&1 & first=$!
run > "$work/second.log" 2>&1 & second=$!
successes=0
if wait "$first"; then successes=$((successes + 1)); fi
if wait "$second"; then successes=$((successes + 1)); fi
[[ $successes == 1 ]] || fail 'concurrent publication must have exactly one winner'
"${gpg_cmd[@]}" --decrypt "$cipher" > "$work/restored.gz" 2>/dev/null
cmp "$work/restored.gz" "$work/input/napay-fixture.sql.gz" || fail 'concurrent output corrupted'
[[ $(find "$work/out" -mindepth 1 -maxdepth 1 | wc -l) == 1 ]] || fail 'concurrent temporary files remain'
pass 'concurrent encryptions publish exactly one complete recoverable backup'
[[ $(sha256sum "$work/input/napay-fixture.sql.gz" | cut -d' ' -f1) == "$original" ]] || fail 'original not preserved'
pass 'original plaintext backup preserved after all tests'
