#!/usr/bin/env bash
# Durable, atomic encrypted backup sets. Does not upload or delete source files.
set -euo pipefail
umask 077
export LC_ALL=C
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
fail() { printf 'Backup set failed: %s\n' "$1" >&2; exit 1; }
source "$(dirname -- "$0")/private-inputs.sh"
verify_set() {
    local directory=$1 line name count=0
    declare -A seen=()
    offsite_private_path "$directory" directory
    offsite_private_path "$directory/manifest.sha256" backup
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ ^[a-f0-9]{64}\ \ ([A-Za-z0-9][A-Za-z0-9._-]{0,179}\.gpg)$ ]] || fail 'invalid manifest entry.'
        name=${BASH_REMATCH[1]}
        [[ ! -v seen[$name] ]] || fail 'duplicate manifest entry.'
        seen[$name]=1
        offsite_private_path "$directory/$name" backup
        count=$((count + 1))
        [[ $count -le 16 ]] || fail 'too many manifest entries.'
    done < "$directory/manifest.sha256"
    [[ $count -gt 0 ]] || fail 'empty manifest.'
    (cd -- "$directory" && sha256sum --strict --status --check manifest.sha256) || fail 'backup set integrity mismatch.'
}
if [[ ${1:-} == --verify ]]; then
    [[ $# -eq 2 ]] || fail 'expected --verify set-directory.'
    verify_set "$2"
    printf 'Backup set integrity verified.\n'
    exit 0
fi
[[ $# -ge 4 && $# -le 19 ]] || fail 'expected public-key, fingerprint, queue-directory and 1-16 backup files.'
key=$1; fingerprint=${2^^}; queue=$3; shift 3
[[ $fingerprint =~ ^([A-F0-9]{40}|[A-F0-9]{64})$ ]] || fail 'a full fingerprint is required.'
offsite_private_path "$key" public
offsite_private_path "$queue" directory
declare -A names=()
identity=$fingerprint
mapfile -d '' -t sources < <(printf '%s\0' "$@" | sort -z)
hashes=()
for file in "${sources[@]}"; do
    offsite_private_path "$file" backup
    name=$(basename -- "$file")
    [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,179}$ && $name != *.partial && $name != *.gpg ]] || fail 'invalid source filename.'
    [[ ! -v names[$name] ]] || fail 'duplicate source filename.'
    names[$name]=1
    hash=$(sha256sum -- "$file" | cut -d' ' -f1)
    hashes+=("$hash")
    identity+=$'\n'"$name:$hash"
done
id=$(printf '%s' "$identity" | sha256sum | cut -d' ' -f1)
final="$queue/set-$id"
if [[ -e $final || -L $final ]]; then
    verify_set "$final"
    printf 'Backup set already sealed: %s\n' "$final"
    exit 0
fi
staging=$(mktemp -d "$queue/.sealing.XXXXXXXX")
trap 'rm -rf -- "$staging"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for index in "${!sources[@]}"; do
    file=${sources[$index]}
    [[ $(sha256sum -- "$file" | cut -d' ' -f1) == "${hashes[$index]}" ]] || fail 'source changed before encryption.'
    bash "$(dirname -- "$0")/encrypt.sh" "$key" "$fingerprint" "$file" "$staging" >/dev/null
    [[ $(sha256sum -- "$file" | cut -d' ' -f1) == "${hashes[$index]}" ]] || fail 'source changed during encryption.'
done
for file in "${sources[@]}"; do
    name=$(basename -- "$file").gpg
    (cd -- "$staging" && sha256sum -- "$name") >> "$staging/manifest.sha256"
done
verify_set "$staging"
# Directory publication is atomic; never replace an existing set or manifest.
mv -T -n -- "$staging" "$final"
verify_set "$final"
printf 'Backup set sealed: %s\n' "$final"
