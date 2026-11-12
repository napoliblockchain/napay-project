#!/usr/bin/env bash
# SIP-022 B0-RV1/RV2: local.sh su albero temporaneo con docker finto. Nessun Docker reale, nessun file fuori dall'albero.
# Ogni caso negativo verifica anche che le sentinelle (contenuto e permessi) restino intatte.
set -euo pipefail
umask 077
src=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
for tool in git realpath flock openssl sha256sum stat mktemp ln; do
    command -v "$tool" >/dev/null || { echo "FAIL: missing prerequisite $tool" >&2; exit 1; }
done
T=$(mktemp -d); T=$(realpath -e -- "$T")
trap 'rm -rf -- "$T"' EXIT
repo=$T/repo
mkdir -p "$repo/docker/btcpay-regtest" "$T/bin" "$T/outside"
cp -- "$src/local.sh" "$src/compose.yml" "$repo/docker/btcpay-regtest/"
git -C "$repo" init -q
# docker finto: registra le chiamate; rete simulata da STUB_NET ("absent" oppure "Internal Driver label")
cat > "$T/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$*" in
    "network inspect -f "*) [[ $STUB_NET == absent ]] && exit 1; printf '%s\n' "$STUB_NET" ;;
    "network inspect "*) [[ $STUB_NET == absent ]] && exit 1; exit 0 ;;
    *"getblockcount"*) echo 101 ;;
esac
exit 0
STUB
chmod 700 "$T/bin/docker"
export PATH="$T/bin:$PATH" STUB_LOG=$T/docker.log STUB_NET='true bridge edge'
sentinel=$T/outside/sentinel
printf 'SENTINEL\n' > "$sentinel"; chmod 640 "$sentinel"
fingerprint() { sha256sum -- "$sentinel" | cut -c1-64; stat -c '%a %s' -- "$sentinel"; }
original=$(fingerprint)
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
run() { BTCPAY_LOCAL_STATE=$1 bash "$repo/docker/btcpay-regtest/local.sh" "${@:2}" >/dev/null 2>&1; }
intact() { [[ $(fingerprint) == "$original" ]] || { echo "FAIL: sentinel changed ($1)" >&2; exit 1; }; }
refused() { # state, label, args...
    local state=$1 label=$2; shift 2
    : > "$STUB_LOG"
    if run "$state" "$@"; then echo "FAIL: accepted: $label" >&2; exit 1; fi
    intact "$label"
    pass "$label"
}

# percorsi
refused "$T/outside/../repo/state" 'Path with ".." resolving into the checkout refused' up
[[ ! -e $repo/state ]] || exit 1
ln -s "$repo" "$T/alias"
refused "$T/alias/state" 'Symlinked ancestor into the checkout refused' up
[[ ! -e $repo/state ]] || exit 1
refused "$repo/state" 'State inside the checkout refused' up
refused "$T" 'State that contains the checkout refused' up
mkdir "$T/outside/real"; ln -s "$T/outside/real" "$T/statelink"
refused "$T/statelink" 'Symlinked state directory refused' up
refused "$T/outside/state/" 'Trailing slash (non canonical) refused' up
refused "$T/missing" 'Status never creates a missing state' status
[[ ! -e $T/missing ]] || exit 1
[[ ! -s $STUB_LOG ]] && pass 'Refused paths never reach docker'

# primo avvio valido
good=$T/outside/state
: > "$STUB_LOG"
STUB_NET=absent run "$good" up
[[ $(stat -c '%a' "$good") == 700 && $(stat -c '%a' "$good/regtest.env") == 600 && $(stat -c '%a' "$good/.gitignore") == 600 ]]
grep -qx '\*' "$good/.gitignore" && [[ -z $(find "$good" -name '.new.*') && ! -e $good/control.lock ]]
pass 'Fresh up: 0700 dir, 0600 secrets and .gitignore, no temp or lock files'
grep -q -- '--internal --driver bridge --label napay.btcpay-regtest=edge' "$STUB_LOG" || exit 1
pass 'Missing edge network created as internal bridge with identity label'
env_sum=$(sha256sum "$good/regtest.env")
run "$good" up
[[ $(sha256sum "$good/regtest.env") == "$env_sum" ]] && pass 'Second up keeps existing secrets'

# vecchio attacco: control.lock symlink verso un file estraneo
ln -s "$sentinel" "$good/control.lock"
run "$good" status
intact 'control.lock symlink'
pass 'Status with control.lock symlink leaves the target untouched'
rm "$good/control.lock"

# file privati dubbi: mai aperti, mai sostituiti
fresh() { rm -rf -- "$T/outside/s2"; mkdir -m 700 "$T/outside/s2"; printf '*\n' > "$T/outside/s2/.gitignore"; }
fresh; ln -s "$T/outside/created-by-attack" "$T/outside/s2/regtest.env"
refused "$T/outside/s2" 'Dangling regtest.env symlink refused' up
[[ ! -e $T/outside/created-by-attack ]] && pass 'Dangling symlink target never created'
fresh; ln -s "$sentinel" "$T/outside/s2/regtest.env"
refused "$T/outside/s2" 'regtest.env symlink to a foreign file refused' up
fresh; printf 'X=1\n' > "$T/outside/s2/regtest.env"; chmod 644 "$T/outside/s2/regtest.env"
refused "$T/outside/s2" 'World-readable regtest.env refused' status
[[ $(cat "$T/outside/s2/regtest.env") == 'X=1' && $(stat -c '%a' "$T/outside/s2/regtest.env") == 644 ]] && pass 'Refused regtest.env left unchanged'
fresh; cp "$sentinel" "$T/outside/copy"; chmod 600 "$T/outside/copy"; ln "$T/outside/copy" "$T/outside/s2/regtest.env"
refused "$T/outside/s2" 'Hard-linked regtest.env refused' up
fresh; mkdir "$T/outside/s2/regtest.env"
refused "$T/outside/s2" 'Directory in place of regtest.env refused' up
rm -rf -- "$T/outside/s2"; mkdir -m 700 "$T/outside/s2"; ln -s "$sentinel" "$T/outside/s2/.gitignore"
refused "$T/outside/s2" '.gitignore symlink refused' up
rm -rf -- "$T/outside/s2"; mkdir -m 700 "$T/outside/s2"; printf 'other\n' > "$T/outside/s2/.gitignore"
refused "$T/outside/s2" '.gitignore not ignoring everything refused' up
[[ ! -e $T/outside/s2/regtest.env ]] && pass 'No secrets written next to a refused .gitignore'

# B0-RV2: rete omonima incompatibile mai riusata ne modificata
for props in 'false bridge edge' 'true overlay edge' 'true bridge <no value>'; do
    STUB_NET=$props refused "$good" "Existing edge network '$props' refused" up
    ! grep -qE 'network (create|rm|connect|disconnect)|compose .* up' "$STUB_LOG" || exit 1
done
pass 'Incompatible networks never modified and stack never started'
printf 'PASS %d local.sh filesystem/network checks\n' "$checks"
