#!/usr/bin/env bash
# Offline transport contract tests: real GPG envelopes, mocked S3 client.
set -euo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
script="$root/docker/backup-offsite/upload.sh"
work=$(mktemp -d)
cleanup() { gpgconf --homedir "$work/recovery" --kill all >/dev/null 2>&1 || true; rm -rf -- "$work"; }
trap cleanup EXIT
mkdir "$work/recovery" "$work/out" "$work/bin"
gpg_cmd=(gpg --no-options --homedir "$work/recovery" --batch --no-tty --pinentry-mode loopback --passphrase '')
"${gpg_cmd[@]}" --quick-generate-key 'Transport fixture <fixture@example.invalid>' rsa2048 encr 0 >/dev/null 2>&1
fingerprint=$("${gpg_cmd[@]}" --with-colons --list-keys 2>/dev/null | awk -F: '$1=="fpr" { print $10; exit }')
"${gpg_cmd[@]}" --export "$fingerprint" > "$work/key.gpg"
printf 'synthetic backup\n' | gzip > "$work/data.sql.gz"
bash "$root/docker/backup-offsite/encrypt.sh" "$work/key.gpg" "$fingerprint" "$work/data.sql.gz" "$work/out" >/dev/null
cipher="$work/out/data.sql.gz.gpg"
cat > "$work/base.env" <<'EOF'
S3_ENDPOINT=https://eu2.contabostorage.com
S3_BUCKET=napay-test
S3_PREFIX=vps-a/napay
S3_REGION=default
S3_ACCESS_KEY_ID=fixture-access-key
S3_SECRET_ACCESS_KEY=fixture-secret-key
EOF
cp "$work/base.env" "$work/config.env"
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
{
    printf '#!/usr/bin/env bash\nset -euo pipefail\nwork=%q\n' "$work"
    cat <<'EOF'
[[ -z ${AWS_ACCESS_KEY_ID:-}${HTTPS_PROXY:-}${RCLONE_CONFIG_OFFSITE_ENDPOINT:-} ]] || exit 81
printf '%s\n' "$@" > "$work/calls"
[[ $1 == copyto ]] || exit 82
[[ $3 == offsite:napay-test/vps-a/napay/*-data.sql.gz.gpg ]] || exit 83
for ((i=1; i<=$#; i++)); do
    if [[ ${!i} == --config ]]; then next=$((i+1)); config=${!next}; fi
done
[[ $(stat -c '%a' "$config") == 600 ]] || exit 84
[[ $(stat -c '%a' "$(dirname "$config")") == 700 ]] || exit 85
grep -q '^secret_access_key = fixture-secret-key$' "$config" || exit 86
[[ ! -e $work/force-fail ]] || { printf 'fixture-secret-key signed-url-detail\n' >&2; exit 42; }
EOF
} > "$work/bin/rclone"
chmod 700 "$work/bin/rclone"
export PATH="$work/bin:$PATH"
bash "$script" --check "$work/config.env" "$cipher" > "$work/log" 2>&1
[[ ! -e $work/calls ]] || fail 'preflight invoked transfer client'
pass 'valid preflight is offline and accepts the real OpenPGP envelope'
AWS_ACCESS_KEY_ID=poison HTTPS_PROXY=http://127.0.0.1:9 RCLONE_CONFIG_OFFSITE_ENDPOINT=http://127.0.0.1:9 \
    bash "$script" "$work/config.env" "$cipher" > "$work/log" 2>&1
for flag in --immutable --checksum --s3-no-check-bucket --retries --low-level-retries --max-duration; do
    grep -qx -- "$flag" "$work/calls" || fail 'missing transport safeguard'
done
[[ $(sed -n '3p' "$work/calls") == *"/$(sha256sum "$cipher" | cut -d' ' -f1)-data.sql.gz.gpg" ]] || fail 'content-addressed destination'
pass 'content-addressed immutable upload uses finite retries and clears client environment'
temp_config=$(awk 'previous=="--config" { print; exit } {previous=$0}' "$work/calls")
[[ ! -e $temp_config ]] || fail 'temporary credentials remain'
pass 'temporary client credentials removed after upload'
touch "$work/force-fail"
if bash "$script" "$work/config.env" "$cipher" > "$work/log" 2>&1; then fail 'client failure hidden'; fi
grep -q 'fixture-secret-key\|signed-url-detail' "$work/log" && fail 'client diagnostics leaked'
[[ -s $cipher && ! -e $temp_config ]] || fail 'local archive lost'
pass 'transfer error is nonzero, redacts SDK output and retains local archive'
rm "$work/force-fail" "$work/calls"
reject() {
    local label=$1; shift
    if "$@" > "$work/log" 2>&1; then fail "$label"; fi
    [[ ! -e $work/calls ]] || fail 'invalid input contacted the transport client'
    pass "$label"
}
check() { bash "$script" --check "$work/config.env" "$cipher"; }
change() { cp "$work/base.env" "$work/config.env"; sed -i "s|^$1=.*|$1=$2|" "$work/config.env"; }
change S3_ENDPOINT http://eu2.contabostorage.com; reject 'plaintext endpoint refused' check
change S3_ENDPOINT https://eu2.contabostorage.com.evil.invalid; reject 'lookalike endpoint refused' check
change S3_ENDPOINT https://user:pass@eu2.contabostorage.com; reject 'URL credentials refused' check
change S3_ENDPOINT https://127.0.0.1; reject 'arbitrary internal endpoint refused' check
change S3_BUCKET ../other; reject 'bucket traversal refused' check
change S3_PREFIX ../other; reject 'prefix traversal refused' check
change S3_REGION 'default extra'; reject 'malformed region refused' check
cp "$work/base.env" "$work/config.env"
long_secret=$(printf '%0256d' 0)
sed -i "s|^S3_SECRET_ACCESS_KEY=.*|S3_SECRET_ACCESS_KEY=$long_secret|" "$work/config.env"
check >/dev/null
pass '256-character credential accepted on both libc implementations'
sed -i "s|^S3_SECRET_ACCESS_KEY=.*|S3_SECRET_ACCESS_KEY=${long_secret}0|" "$work/config.env"
reject 'overlong credential refused' check
grep -v '^S3_REGION=' "$work/base.env" > "$work/config.env"
printf 'S3_REGION=$(touch %q)\n' "$work/evaluated" >> "$work/config.env"
reject 'shell expression is not evaluated as configuration' check
[[ ! -e $work/evaluated ]] || fail 'configuration executed a command'
cp "$work/base.env" "$work/config.env"; printf 'RCLONE_INSECURE=true\n' >> "$work/config.env"
reject 'unknown override refused' check
cp "$work/base.env" "$work/config.env"; printf 'S3_REGION=default\n' >> "$work/config.env"
reject 'duplicate configuration refused' check
cp "$work/base.env" "$work/config.env"; chmod 644 "$work/config.env"
reject 'readable-by-others credentials refused' check
chmod 600 "$work/config.env"
reject 'plaintext backup refused' bash "$script" --check "$work/config.env" "$work/data.sql.gz"
printf 'not really encrypted\n' > "$work/fake.gpg"
reject 'renamed plaintext envelope refused' bash "$script" --check "$work/config.env" "$work/fake.gpg"
pass 'no S3 service or production configuration was used'
