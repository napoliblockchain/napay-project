#!/usr/bin/env bash
# Offline SIP-038 primitive. The production tools container is a separate step.
set -euo pipefail
umask 077
export LC_ALL=C
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
fail() { printf 'Backup encryption failed: %s\n' "$1" >&2; exit 1; }
[[ $# -eq 4 ]] || fail 'expected public-key, fingerprint, backup-file, output-directory.'
key=$1; fingerprint=${2^^}; source_file=$3; output=$4
[[ $fingerprint =~ ^([A-F0-9]{40}|[A-F0-9]{64})$ ]] || fail 'a full fingerprint is required.'
for utility in gpg realpath stat mktemp awk ln; do
    command -v "$utility" >/dev/null || fail 'a required offline tool is unavailable.'
done
source "$(dirname -- "$0")/private-inputs.sh"
offsite_private_path "$key" public
offsite_private_path "$source_file" backup
offsite_private_path "$output" directory
name=$(basename -- "$source_file")
[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,179}$ && $name != *.partial && $name != *.gpg ]] \
    || fail 'backup filename is invalid or incomplete.'
final="$output/$name.gpg"
[[ ! -e $final && ! -L $final ]] || fail 'encrypted destination already exists.'
home=''; partial=''
cleanup() {
    [[ -z $partial ]] || rm -f -- "$partial"
    [[ -z $home ]] || rm -rf -- "$home"
    return 0
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
home=$(mktemp -d "$output/.encrypt-home.XXXXXXXX")
gpg_cmd=(gpg --no-options --homedir "$home" --batch --no-tty --no-auto-key-retrieve --auto-key-locate clear)
# Inspect before importing: a server must never ingest a private recovery key.
listing=$("${gpg_cmd[@]}" --with-colons --show-keys -- "$key" 2>/dev/null) || fail 'public key cannot be inspected.'
[[ $(awk -F: '$1 == "pub" { n++ } END { print n+0 }' <<< "$listing") == 1 ]] \
    || fail 'exactly one primary public key is required.'
if awk -F: '$1 == "sec" || $1 == "ssb" { found=1 } END { exit !found }' <<< "$listing"; then
    fail 'private keys are forbidden on the encryption side.'
fi
actual=$(awk -F: '$1 == "pub" { primary=1; next } primary && $1 == "fpr" { print $10; exit }' <<< "$listing")
[[ $actual == "$fingerprint" ]] || fail 'public key fingerprint does not match.'
"${gpg_cmd[@]}" --import -- "$key" >/dev/null 2>&1 || fail 'public key import failed.'
partial=$(mktemp "$output/.encrypt-data.XXXXXXXX")
# Trust is pinned to the independently supplied full fingerprint, never a UID.
"${gpg_cmd[@]}" --trust-model always --cipher-algo AES256 --compress-algo none \
    --set-filename '' --recipient "$fingerprint" --encrypt < "$source_file" > "$partial" 2>/dev/null \
    || fail 'encryption did not complete.'
[[ -s $partial ]] || fail 'encrypted output is empty.'
chmod 600 "$partial"
# Atomic publication without replacement, including concurrent invocations.
ln -T -- "$partial" "$final" 2>/dev/null || fail 'encrypted destination cannot be published.'
printf 'Backup encryption complete.\n'
