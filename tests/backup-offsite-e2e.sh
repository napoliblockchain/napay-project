#!/usr/bin/env bash
# Disposable TLS S3 fixture. No public ports, real credentials or external S3.
set -euo pipefail
umask 077
image=${BACKUP_TOOLS_IMAGE:-napay/backup-offsite:sip038-test}
work=$(mktemp -d)
run="sip038-$(date +%s)-$RANDOM"
network="$run-net"; server="$run-s3"
cleanup() {
    docker rm -f "$server" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
    gpgconf --homedir "$work/recovery" --kill all >/dev/null 2>&1 || true
    rm -rf -- "$work"
}
trap cleanup EXIT
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$work/recovery" "$work/out" "$work/storage/napay-test" "$work/download"
gpg_cmd=(gpg --no-options --homedir "$work/recovery" --batch --no-tty --pinentry-mode loopback --passphrase '')
"${gpg_cmd[@]}" --quick-generate-key 'S3 recovery fixture <fixture@example.invalid>' rsa2048 encr 0 >/dev/null 2>&1
fingerprint=$("${gpg_cmd[@]}" --with-colons --list-keys 2>/dev/null | awk -F: '$1=="fpr" { print $10; exit }')
"${gpg_cmd[@]}" --export "$fingerprint" > "$work/public.gpg"
printf 'exact synthetic restore from TLS S3\n' | gzip > "$work/data.sql.gz"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=SIP038 test CA' \
    -keyout "$work/ca.key" -out "$work/ca.crt" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj '/CN=eu2.contabostorage.com' \
    -keyout "$work/server.key" -out "$work/server.csr" >/dev/null 2>&1
printf 'subjectAltName=DNS:eu2.contabostorage.com\nextendedKeyUsage=serverAuth\n' > "$work/extensions"
openssl x509 -req -in "$work/server.csr" -CA "$work/ca.crt" -CAkey "$work/ca.key" \
    -CAcreateserial -days 1 -extfile "$work/extensions" -out "$work/server.crt" >/dev/null 2>&1
cat > "$work/config.env" <<'EOF'
S3_ENDPOINT=https://eu2.contabostorage.com
S3_BUCKET=napay-test
S3_PREFIX=vps-a/napay
S3_REGION=default
S3_ACCESS_KEY_ID=fixture-access-key
S3_SECRET_ACCESS_KEY=fixture-secret-key
EOF
runtime=(--rm --user "$(id -u):$(id -g)" --read-only --cap-drop ALL --security-opt no-new-privileges \
    --memory 256m --cpus 1 --pids-limit 64 --tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m)
docker run "${runtime[@]}" --network none \
    -v "$work/public.gpg:/inputs/public.gpg:ro" -v "$work/data.sql.gz:/inputs/data.sql.gz:ro" \
    -v "$work/out:/output" "$image" encrypt /inputs/public.gpg "$fingerprint" /inputs/data.sql.gz /output >/dev/null
cipher="$work/out/data.sql.gz.gpg"
[[ -s $cipher ]] || fail 'container encryption'
pass 'non-root read-only container encrypts without network or private recovery key'
docker run "${runtime[@]}" --network none -v "$work/config.env:/inputs/config.env:ro" \
    -v "$cipher:/inputs/data.sql.gz.gpg:ro" "$image" upload --check /inputs/config.env /inputs/data.sql.gz.gpg >/dev/null
pass 'container preflight succeeds with network disabled'
docker network create --internal "$network" >/dev/null
# Permit non-root port 443 in this disposable namespace only; publish nothing.
docker run -d --name "$server" --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
    --sysctl net.ipv4.ip_unprivileged_port_start=0 \
    --security-opt no-new-privileges --memory 256m --cpus 1 --pids-limit 64 \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m --network "$network" \
    --network-alias eu2.contabostorage.com --network-alias wrong.contabostorage.com \
    -v "$work/storage:/storage" -v "$work/server.crt:/tls/server.crt:ro" \
    -v "$work/server.key:/tls/server.key:ro" --entrypoint rclone "$image" serve s3 /storage \
    --addr :443 --cert /tls/server.crt --key /tls/server.key \
    --auth-key fixture-access-key,fixture-secret-key --min-tls-version tls1.2 >/dev/null
upload() {
    local config=$1; shift
    docker run "${runtime[@]}" --network "$network" -v "$config:/inputs/config.env:ro" \
        -v "$cipher:/inputs/data.sql.gz.gpg:ro" -v "$work/ca.crt:/inputs/ca.crt:ro" \
        "$image" upload /inputs/config.env /inputs/data.sql.gz.gpg "$@"
}
upload "$work/config.env" /inputs/ca.crt > "$work/upload.log" 2>&1 || { cat "$work/upload.log"; fail 'real TLS S3 upload'; }
digest=$(sha256sum "$cipher" | cut -d' ' -f1)
object="vps-a/napay/$digest-data.sql.gz.gpg"
remote="$work/storage/napay-test/$object"
cmp "$cipher" "$remote" || fail 'stored ciphertext mismatch'
pass 'real rclone uploads ciphertext to isolated TLS S3 with trusted CA'
upload "$work/config.env" /inputs/ca.crt >/dev/null
cmp "$cipher" "$remote" || fail 'retry changed remote bytes'
pass 'identical retry succeeds without changing encrypted content'
if upload "$work/config.env" > "$work/rejected.log" 2>&1; then fail 'untrusted TLS accepted'; fi
pass 'untrusted TLS certificate rejected without verification bypass'
sed 's/eu2.contabostorage.com/wrong.contabostorage.com/' "$work/config.env" > "$work/wrong.env"
if upload "$work/wrong.env" /inputs/ca.crt > "$work/rejected.log" 2>&1; then fail 'wrong hostname accepted'; fi
pass 'TLS hostname mismatch rejected with otherwise trusted CA'
sed 's/fixture-secret-key/incorrect-secret-key/' "$work/config.env" > "$work/denied.env"
if upload "$work/denied.env" /inputs/ca.crt > "$work/rejected.log" 2>&1; then fail 'invalid credentials accepted'; fi
pass 'invalid S3 credentials refused by the real fixture server'
cat > "$work/restore.conf" <<'EOF'
[offsite]
type = s3
provider = Other
env_auth = false
endpoint = https://eu2.contabostorage.com
region = default
access_key_id = fixture-access-key
secret_access_key = fixture-secret-key
EOF
docker run "${runtime[@]}" --network "$network" -v "$work/restore.conf:/inputs/restore.conf:ro" \
    -v "$work/ca.crt:/inputs/ca.crt:ro" -v "$work/download:/download" --entrypoint rclone "$image" \
    copyto "offsite:napay-test/$object" /download/recovered.gpg --config /inputs/restore.conf \
    --ca-cert /inputs/ca.crt --retries 1 --timeout 10s >/dev/null 2>&1
"${gpg_cmd[@]}" --decrypt "$work/download/recovered.gpg" > "$work/restored.gz" 2>/dev/null
cmp "$work/restored.gz" "$work/data.sql.gz" || fail 'downloaded recovery mismatch'
gzip -t "$work/restored.gz"
pass 'download, offline decryption and exact original-byte recovery succeed'
printf 'different remote bytes\n' > "$remote"
if upload "$work/config.env" /inputs/ca.crt > "$work/rejected.log" 2>&1; then fail 'different existing object overwritten'; fi
grep -q '^different remote bytes$' "$remote" || fail 'remote collision changed'
pass 'different existing remote object is not overwritten'
[[ $(docker inspect --format '{{len .HostConfig.PortBindings}}' "$server") == 0 ]] || fail 'public server port'
pass 'fixture publishes no host ports and uses only an internal Docker network'
