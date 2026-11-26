#!/usr/bin/env bash
# Upload a completed OpenPGP archive, never an unencrypted backup.
set -euo pipefail
umask 077
export LC_ALL=C
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
fail() { printf 'Backup upload failed: %s\n' "$1" >&2; exit 1; }
check=false
if [[ ${1:-} == --check ]]; then check=true; shift; fi
[[ $# -eq 2 || $# -eq 3 ]] || fail 'expected config-file, encrypted-file and optional CA-file.'
config=$1; encrypted=$2; ca=${3:-}
source "$(dirname -- "$0")/private-inputs.sh"
offsite_private_path "$config" config
offsite_private_path "$encrypted" backup
[[ -z $ca ]] || offsite_private_path "$ca" public
[[ $(stat -c '%s' -- "$config") -le 16384 ]] || fail 'configuration is too large.'
declare -A values=()
while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || $line == \#* ]] && continue
    [[ $line != *$'\r'* && $line == *=* ]] || fail 'malformed configuration line.'
    field=${line%%=*}; value=${line#*=}
    case $field in
        S3_ENDPOINT|S3_BUCKET|S3_PREFIX|S3_REGION|S3_ACCESS_KEY_ID|S3_SECRET_ACCESS_KEY) ;;
        *) fail 'unsupported configuration field.' ;;
    esac
    [[ ! -v values[$field] && -n $value ]] || fail 'duplicate or empty configuration field.'
    values[$field]=$value
done < "$config"
for field in S3_ENDPOINT S3_BUCKET S3_PREFIX S3_REGION S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY; do
    [[ -v values[$field] ]] || fail 'required configuration field is missing.'
done
[[ ${values[S3_ENDPOINT]} =~ ^https://[a-z0-9][a-z0-9-]{0,62}\.contabostorage\.com$ ]] \
    || fail 'a Contabo HTTPS endpoint without path or credentials is required.'
[[ ${values[S3_BUCKET]} =~ ^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$ ]] || fail 'invalid bucket name.'
[[ ${values[S3_PREFIX]} =~ ^[a-zA-Z0-9][a-zA-Z0-9_/-]{0,119}$ && ${values[S3_PREFIX]} != */ \
    && ${values[S3_PREFIX]} != *//* ]] || fail 'invalid backup prefix.'
[[ ${values[S3_REGION]} =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,39}$ ]] || fail 'invalid S3 region.'
for field in S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY; do
    value=${values[$field]}
    [[ $value =~ ^[A-Za-z0-9/+=_-]+$ && ${#value} -ge 8 && ${#value} -le 256 ]] \
        || fail 'invalid credential format.'
done
name=$(basename -- "$encrypted")
[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,179}\.gpg$ ]] || fail 'expected a completed .gpg archive.'
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$scratch/gnupg"
packets=$(gpg --no-options --homedir "$scratch/gnupg" --batch --no-tty \
    --no-auto-key-retrieve --auto-key-locate clear --list-only --list-packets \
    -- "$encrypted" 2>/dev/null) || fail 'archive packet inspection failed.'
[[ $packets == *':pubkey enc packet:'* \
    && ( $packets == *':encrypted data packet:'* || $packets == *':aead encrypted packet:'* ) \
    && $packets != *':literal data packet:'* ]] || fail 'archive is not an asymmetric encrypted envelope.'
if $check; then
    printf 'Backup upload preflight complete; no network request made.\n'
    exit 0
fi
command -v rclone >/dev/null || fail 'rclone is unavailable.'
# Do not inherit credentials, proxies, debug options or backend overrides.
client=(env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch" LC_ALL=C rclone)
{
    printf '[offsite]\ntype = s3\nprovider = Other\nenv_auth = false\n'
    printf 'endpoint = %s\nregion = %s\n' "${values[S3_ENDPOINT]}" "${values[S3_REGION]}"
    printf 'access_key_id = %s\nsecret_access_key = %s\n' "${values[S3_ACCESS_KEY_ID]}" "${values[S3_SECRET_ACCESS_KEY]}"
} > "$scratch/rclone.conf"
digest=$(sha256sum -- "$encrypted" | cut -d' ' -f1)
destination="offsite:${values[S3_BUCKET]}/${values[S3_PREFIX]}/$digest-$name"
options=(--config "$scratch/rclone.conf" --immutable --checksum --retries 3 \
    --low-level-retries 2 --contimeout 5s --timeout 30s --max-duration 5m \
    --transfers 1 --checkers 1 --multi-thread-streams 0 --s3-upload-concurrency 1 \
    --s3-chunk-size 8Mi --s3-no-check-bucket --stats 0 --log-level ERROR)
[[ -z $ca ]] || options+=(--ca-cert "$ca")
# Raw SDK diagnostics can contain credentials or signed URLs; never relay them.
"${client[@]}" copyto "$encrypted" "$destination" "${options[@]}" >/dev/null 2>&1 \
    || fail 'transfer or remote verification failed; local archive retained.'
printf 'Backup upload complete.\n'
