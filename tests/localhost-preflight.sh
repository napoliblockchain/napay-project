#!/usr/bin/env bash
# Launcher contract with private fake state. No real Docker commands, services or credentials.
set -euo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d)
trap 'code=$?; if (( code != 0 )); then cat "$work/output" >&2 2>/dev/null || true; fi; rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$work/bin" "$work/project/napay/docker" "$work/project/poawallet" "$work/state"
cp "$root/start-localhost.sh" "$work/project/start-localhost.sh"
printf 'NAPAY_LOCAL_STATE=%s\nGATEWAY_HTTP_PORT=80\nGATEWAY_HTTPS_PORT=443\n' "$work/state" > "$work/project/.env"
: > "$work/project/poawallet/.env"; : > "$work/project/napay/docker-compose.roles.yml"
cat > "$work/bin/docker" <<'SH'
#!/usr/bin/env bash
case "$*" in
    info|image\ inspect\ *) exit 0 ;;
    ps\ *) printf 'napay-gateway\n'; exit 0 ;;
esac
touch "$PREFLIGHT_TEST_PERSISTENT"
echo 'Unexpected Docker operation refused.' >&2; exit 1
SH
cat > "$work/bin/grep" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do [[ $arg != /etc/hosts ]] || exit 0; done
exec "$PREFLIGHT_TEST_GREP" "$@"
SH
cat > "$work/project/napay/docker/local.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ $NAPAY_LOCAL_STATE == "$PREFLIGHT_TEST_STATE" ]] || exit 1
printf '%s\n' "$1" >> "$PREFLIGHT_TEST_CALLS"
case "$1" in
    init) [[ ! -e $PREFLIGHT_TEST_STATE/refuse-init ]] || exit 1; : > "$NAPAY_LOCAL_STATE/local.env" ;;
    check) [[ ! -e $PREFLIGHT_TEST_STATE/refuse-check ]] ;;
    *) exit 1 ;;
esac
SH
chmod 700 "$work/bin/"*
checks=0
run_launcher() {
    : > "$work/calls"
    env -i PATH="$work/bin:$PATH" HOME="$HOME" NAPAY_IMPORT_DIR="$work/dataset" \
        PREFLIGHT_TEST_GREP="$(command -v grep)" PREFLIGHT_TEST_STATE="$work/state" \
        PREFLIGHT_TEST_CALLS="$work/calls" PREFLIGHT_TEST_PERSISTENT="$work/persistent" \
        bash "$work/project/start-localhost.sh" "$@" > "$work/output" 2>&1
}
pass() { [[ ! -e $work/persistent ]]; checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
reject() { if run_launcher "$@"; then echo 'FAIL: invalid preflight accepted.' >&2; exit 1; fi; }
: > "$work/state/local.env"
run_launcher --check
[[ $(cat "$work/calls") == check ]]
pass 'Existing role-enabled Napay is checked before launcher returns success'
touch "$work/state/refuse-check"
reject --check; [[ $(cat "$work/calls") == check ]]
pass 'Invalid role configuration blocks check before any service operation'
reject; [[ $(cat "$work/calls") == check ]]
pass 'Invalid role configuration blocks normal startup before other stacks'
rm "$work/state/local.env"
reject --check; [[ ! -s $work/calls && ! -e $work/state/local.env ]]
pass 'Check on fresh state creates no credentials and starts nothing'
reject; [[ $(cat "$work/calls") == $'init\ncheck' && -f $work/state/local.env ]]
pass 'First normal startup initializes then validates Napay before other stacks'
rm "$work/state/local.env"; touch "$work/state/refuse-init"
reject; [[ $(cat "$work/calls") == init && ! -e $work/state/local.env ]]
pass 'Failed private initialization blocks startup without service operations'
rm "$work/project/napay/docker-compose.roles.yml"
run_launcher --check; [[ ! -s $work/calls ]]
pass 'Older Napay checkout remains compatible until role overlay integration'
printf 'PASS %s localhost preflight checks\n' "$checks"
