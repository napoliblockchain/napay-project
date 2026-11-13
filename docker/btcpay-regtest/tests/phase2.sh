#!/usr/bin/env bash
# SIP-022 B0 fase 2: comportamento reale di BTCPay 2.4.7 per il provisioning (utenti, store, app POS, chiavi).
# Istanza regtest usa-e-getta, HTTP diretto sulla rete interna del test (autorizzato solo per queste prove:
# il trasporto applicativo resta proxy + TLS). Segreti solo in una cartella 0700 temporanea, mai stampati.
set -euo pipefail
umask 077
dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
for tool in docker openssl od python3 realpath base64; do command -v "$tool" >/dev/null || { echo "FAIL: missing prerequisite $tool" >&2; exit 1; }; done
run=$(openssl rand -hex 4)
export BTCPAY_PROJECT="btcpay-p2-$run" BTCPAY_EDGE_NETWORK="btcpay_p2_$run"
export BTCPAY_EDGE_SUBNET="10.254.$(( $(od -An -N1 -tu1 /dev/urandom) % 200 + 20 )).0/24"
work=$(realpath -e -- "$(mktemp -d)")
export BTCPAY_LOCAL_STATE="$work/state"
client=$(sed -n 's/^ *image: \(nicolasdorier\/nbxplorer:.*\)$/\1/p' "$dir/compose.yml")
domain=btcpay-merchants.jamprojects.it
checks=0
pass() { checks=$((checks + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
cleanup() {
    code=$?
    trap - EXIT
    bash "$dir/local.sh" reset --yes >/dev/null 2>&1 || true
    docker network rm "$BTCPAY_EDGE_NETWORK" >/dev/null 2>&1 || true
    rm -rf -- "$work"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# api METODO PERCORSO [file-corpo] [file-intestazione] -> $code; risposta in $work/out.json (mai stampata intera)
api() {
    local method=$1 path=$2 body=${3:-} auth=${4:-} args arg
    # URL (puo contenere una chiave) in un file di configurazione curl privato, mai negli argomenti di processo
    printf 'url = "http://btcpay-regtest:49392%s"\n' "$path" > "$work/request.cfg"
    args=(-s -o /w/out.json -D /w/headers.txt -w '%{http_code}' -X "$method" --max-time 30 -K /w/request.cfg)
    [[ -z $auth ]] || { [[ -s $work/$auth ]] || fail "missing credential file $auth"; args+=(-H "@/w/$auth"); }
    [[ -z $body ]] || args+=(-H 'Content-Type: application/json' --data-binary "@/w/$body")
    # controllo automatico: nessun argomento di curl simile a un segreto (chiavi, password, token)
    for arg in "${args[@]}"; do [[ ! $arg =~ [A-Za-z0-9+/=_-]{24,} ]] || fail 'secret-like value in process arguments'; done
    code=$(docker run --rm --user "$(id -u):$(id -g)" --network "$BTCPAY_EDGE_NETWORK" -v "$work:/w" --entrypoint curl "$client" "${args[@]}") || code=000
    rm -f "$work/request.cfg"
}
# come api, ma su 429 rispetta Retry-After (massimo 3 attese da 90 s): comportamento atteso dal worker
throttled=0
api_retry() {
    local attempt wait
    for attempt in 1 2 3 4; do
        api "$@"
        [[ $code == 429 ]] || return 0
        throttled=$((throttled + 1))
        wait=$(sed -n 's/^[Rr]etry-[Aa]fter: *\([0-9]*\).*/\1/p' "$work/headers.txt" | head -1)
        [[ $wait =~ ^[0-9]+$ ]] || wait=10
        (( wait <= 90 )) || fail "Retry-After too long ($wait s)"
        printf 'INFO: 429, Retry-After %s s\n' "$wait"
        sleep "$((wait + 1))"
    done
}
json() { python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); print($1)" "$work/out.json"; }
# file corpo JSON costruito da python (valori mai in argomenti di processi docker)
# corpo da stdin (anche le password): nessun valore negli argomenti di processo
body() { python3 -I -c "import ast,json,sys; open(sys.argv[1],'w').write(json.dumps(ast.literal_eval(sys.stdin.read())))" "$work/$1" <<< "$2"; }
basic() { printf 'Authorization: Basic %s\n' "$(printf '%s:%s' "$2" "$3" | base64 -w0)" > "$work/$1"; }
# chiave dalla risposta in un file intestazione, poi risposta cancellata
keyfile() { python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); open(sys.argv[2],'w').write('Authorization: token '+d['apiKey']+'\n')" "$work/out.json" "$work/$1"; rm -f "$work/out.json"; }
newkey() { # nome-file permessi-json
    body key.json "{'label': '$1', 'permissions': $2}"
    api POST /api/v1/api-keys key.json admin.hdr
    [[ $code == 200 ]] || fail "admin cannot create key $1 ($code)"
    keyfile "$1"
}

docker run --rm --network none --entrypoint curl "$client" --version >/dev/null
bash "$dir/local.sh" up >/dev/null
pass 'Disposable regtest instance healthy'

# --- amministratore iniziale e politica di registrazione
admin_pw=$(openssl rand -hex 24)
body admin.json "{'email': 'b0-admin@$domain', 'password': '$admin_pw', 'isAdministrator': True}"
basic admin.hdr "b0-admin@$domain" "$admin_pw"; unset admin_pw
api POST /api/v1/users admin.json
[[ $code == 201 && $(json "'ServerAdmin' in d['roles']") == True ]] || fail "first admin ($code)"
pass 'First administrator created without authentication (empty instance only)'
body anon.json "{'email': 'b0-anon@$domain', 'password': '$(openssl rand -hex 24)', 'isAdministrator': False}"
api POST /api/v1/users anon.json
[[ $code == 401 ]] || fail "anonymous registration after first admin ($code)"
pass 'Anonymous user creation refused once an admin exists (401)'

# --- contratto OpenAPI e permessi dichiarati
api GET /swagger/v1/swagger.json "" admin.hdr
[[ $code == 200 ]] || fail "OpenAPI with admin ($code)"
cp "$work/out.json" "$work/swagger.json"
printf 'INFO: OpenAPI sha256 %s, %s paths\n' "$(sha256sum "$work/swagger.json" | cut -c1-16)" "$(json "len(d['paths'])")"
python3 -I - "$work/swagger.json" <<'PY' | sed 's/^/MATRIX: /'
import json, sys
d = json.load(open(sys.argv[1]))
ops = [('post', '/api/v1/users'), ('get', '/api/v1/users/{idOrEmail}'), ('post', '/api/v1/stores'),
       ('get', '/api/v1/stores'), ('post', '/api/v1/stores/{storeId}/users'), ('get', '/api/v1/stores/{storeId}/users'),
       ('post', '/api/v1/stores/{storeId}/apps/pos'), ('get', '/api/v1/stores/{storeId}/apps'),
       ('post', '/api/v1/api-keys'), ('post', '/api/v1/users/{idOrEmail}/api-keys'), ('delete', '/api/v1/api-keys/current')]
for method, path in ops:
    sec = d['paths'][path][method].get('security', [])
    print(f"{method.upper()} {path} | dichiarato: {', '.join(p for s in sec for p in s.get('API_Key', [])) or '-'}")
PY
pass 'OpenAPI downloaded with admin credentials; declared permissions listed'

# --- provisioner minimo: solo utenti
newkey prov.hdr "['btcpay.server.cancreateuser', 'btcpay.server.canviewusers']"
declare -A pw
for m in a b; do
    pw[$m]=$(openssl rand -hex 24)
    body "user-$m.json" "{'email': 'm-$m@$domain', 'password': '${pw[$m]}', 'isAdministrator': False}"
    basic "basic-$m.hdr" "m-$m@$domain" "${pw[$m]}"
    api_retry POST /api/v1/users "user-$m.json" prov.hdr
    [[ $code == 201 ]] || fail "create merchant user $m ($code)"
done
printf 'INFO: user flags %s\n' "$(json "{k: d.get(k) for k in ['roles','emailConfirmed','requiresEmailConfirmation','approved','requiresApproval','disabled']}")"
unset pw
pass 'Provisioner (cancreateuser, canviewusers) creates merchant users with random passwords'
api_retry POST /api/v1/users user-a.json prov.hdr
[[ $code == 422 ]] || fail "duplicate user ($code)"
pass 'Same email again refused (422): no duplicate identity'
api GET "/api/v1/users/m-a@$domain" "" prov.hdr
[[ $code == 200 ]] || fail "lookup by email ($code)"
pass 'Reconciliation lookup by technical email (200)'
# gate B1: il provisioner non deve poter creare amministratori del server
body admin-try.json "{'email': 'b0-escalation@$domain', 'password': '$(openssl rand -hex 24)', 'isAdministrator': True}"
api_retry POST /api/v1/users admin-try.json prov.hdr
escalation=$code
api_retry GET "/api/v1/users/b0-escalation@$domain" "" prov.hdr
printf 'INFO: provisioner isAdministrator=true -> %s; lookup %s\n' "$escalation" "$code"
[[ $escalation == 403 && $code == 404 ]] || fail 'provisioner could create a server admin'
pass 'Provisioner (cancreateuser) cannot create a server administrator'
body store-x.json "{'name': 'Negozio provisioner'}"
api POST /api/v1/stores store-x.json prov.hdr
[[ $code == 403 ]] || fail "provisioner store creation without store permission ($code)"
pass 'Minimal provisioner cannot create stores (403)'

# --- percorso P1 (store del provisioner + utente aggiunto): permessi server necessari
newkey store-admin.hdr "['btcpay.store.canmodifystoresettings']"
api POST /api/v1/stores store-x.json store-admin.hdr
[[ $code == 200 ]] || fail "admin store ($code)"
store_x=$(json "d['id']")
# utente dedicato alla prova P1, distinto dai merchant del percorso P3
body user-p1.json "{'email': 'm-p1@$domain', 'password': '$(openssl rand -hex 24)', 'isAdministrator': False}"
api_retry POST /api/v1/users user-p1.json prov.hdr
[[ $code == 201 ]] || fail "create P1 user ($code)"
user_a=$(json "d['id']")
body add-direct.json "{'id': '$user_a', 'storeRole': 'Owner', 'requireInvitation': False}"
api POST "/api/v1/stores/$store_x/users" add-direct.json store-admin.hdr
[[ $code == 403 && $(json "d.get('code')") == missing-permission ]] || fail "direct add without server settings ($code)"
pass 'P1: adding a user to a store without invitation needs server settings permission (403)'
body add-invite.json "{'id': '$user_a', 'storeRole': 'Owner'}"
api POST "/api/v1/stores/$store_x/users" add-invite.json store-admin.hdr
[[ $code == 200 ]] || fail "add with invitation ($code)"
api GET "/api/v1/stores/$store_x/users" "" store-admin.hdr
[[ $(json "any(m.get('id') == '$user_a' for m in d)") == False ]] || fail 'invited user became a member'
pass 'P1: default add creates an invitation, the merchant is not a member until accepted'
newkey server.hdr "['btcpay.store.canmodifystoresettings', 'btcpay.server.canmodifyserversettings']"
api POST "/api/v1/stores/$store_x/users" add-direct.json server.hdr
api GET "/api/v1/stores/$store_x/users" "" store-admin.hdr
[[ $(json "any(m.get('id') == '$user_a' and m.get('roleId') == 'Owner' for m in d)") == True ]] || fail 'direct add with server settings'
pass 'P1: direct add works only with btcpay.server.canmodifyserversettings'

# --- chiavi per conto di altri utenti: permesso reale diverso da quello dichiarato
newkey manage.hdr "['btcpay.server.canmanageusers', 'btcpay.store.canmodifystoresettings']"
body merchant-key.json "{'label': 'merchant-store', 'permissions': ['btcpay.store.canmodifystoresettings']}"
api POST "/api/v1/users/m-b@$domain/api-keys" merchant-key.json manage.hdr
[[ $code == 403 && $(json "d.get('missingPermission')") == btcpay.server.canmodifyserversettings ]] || fail "key for another user ($code)"
pass 'Keys for other users need canmodifyserversettings in practice (OpenAPI declares canmanageusers)'
body unrestricted.json "{'label': 'escalation', 'permissions': ['unrestricted']}"
api POST "/api/v1/users/b0-admin@$domain/api-keys" unrestricted.json manage.hdr
[[ $code == 403 ]] || fail "escalation to admin key ($code)"
pass 'canmanageusers cannot mint keys for the admin (403)'

# --- percorso P3: il merchant crea una propria chiave limitata con la password una sola volta
for m in a b; do
    api POST /api/v1/api-keys merchant-key.json "basic-$m.hdr"
    [[ $code == 200 && $(json "d['permissions']") == "['btcpay.store.canmodifystoresettings']" ]] || fail "merchant $m own key ($code)"
    keyfile "key-$m.hdr"
    # decisione B: la password tecnica del merchant a resta (cifrata nel worker reale; qui solo nella cartella 0700 del test)
    [[ $m == a ]] || rm -f "$work/basic-$m.hdr"
    body "store-$m.json" "{'name': 'Negozio $m'}"
    api POST /api/v1/stores "store-$m.json" "key-$m.hdr"
    [[ $code == 200 ]] || fail "merchant $m store ($code)"
    json "d['id']" > "$work/store-$m"
    api GET "/api/v1/stores/$(cat "$work/store-$m")/users" "" "key-$m.hdr"
    [[ $(json "[x.get('roleId') for x in d]") == "['Owner']" ]] || fail "merchant $m sole owner"
    body "pos-$m.json" "{'appName': 'POS $m'}"
    api POST "/api/v1/stores/$(cat "$work/store-$m")/apps/pos" "pos-$m.json" "key-$m.hdr"
    [[ $code == 200 && $(json "d.get('appType')") == PointOfSale ]] || fail "merchant $m POS app ($code)"
done
pass 'P3: merchant-owned key (store settings only) creates own store as sole Owner and a POS app'
api GET "/api/v1/stores/$(cat "$work/store-b")" "" key-a.hdr
[[ $code == 403 ]] || fail "cross-merchant store ($code)"
api GET /api/v1/stores "" key-a.hdr
[[ $(json "[s['id'] for s in d]") == "['$(cat "$work/store-a")']" ]] || fail 'merchant a store list'
pass 'P3: each merchant key sees only its own store (other store 403)'
api POST /api/v1/api-keys unrestricted.json key-a.hdr
[[ $code == 403 ]] || fail "merchant key minting keys ($code)"
pass 'P3: merchant store key cannot create further keys (403)'
api GET "/api/v1/stores/$(cat "$work/store-a")/apps" "" key-a.hdr
[[ $code == 200 && $(json "len(d)") == 1 ]] || fail "apps listing ($code)"
pass 'Reconciliation: POS apps of a store listed with the merchant key'

# --- decisione B: rotazione della chiave del merchant con la password tecnica conservata (R1-R4)
ids() { json "sorted(x['id'] for x in d)"; }
api GET /api/v1/stores "" key-a.hdr; stores_old=$(ids)
api GET "/api/v1/stores/$(cat "$work/store-a")/apps" "" key-a.hdr; apps_old=$(ids)
api POST /api/v1/api-keys merchant-key.json basic-a.hdr
[[ $code == 200 && $(json "d['permissions']") == "['btcpay.store.canmodifystoresettings']" ]] || fail "R1 new key ($code)"
keyfile key-a2.hdr
pass 'R1: stored technical password mints a second key limited to store settings'
api GET /api/v1/stores "" key-a2.hdr
[[ $code == 200 && $(ids) == "$stores_old" ]] || fail 'R2 stores'
api GET "/api/v1/stores/$(cat "$work/store-a")/apps" "" key-a2.hdr
[[ $code == 200 && $(ids) == "$apps_old" ]] || fail 'R2 apps'
api GET "/api/v1/stores/$(cat "$work/store-b")" "" key-a2.hdr
[[ $code == 403 ]] || fail "R2 foreign store ($code)"
pass 'R2: new key sees exactly the same stores and POS apps, not other merchants'
api GET /api/v1/stores "" key-a.hdr
[[ $code == 200 ]] || fail "R3 old key ($code)"
pass 'R3: old key still valid while the new one is in place'
api POST /api/v1/api-keys unrestricted.json key-a2.hdr
[[ $code == 403 ]] || fail "new key minting ($code)"
pass 'New key cannot create further keys (403)'
api DELETE /api/v1/api-keys/current "" key-a.hdr
[[ $code == 200 ]] || fail "R4 revoke ($code)"
api GET /api/v1/stores "" key-a.hdr; old_after=$code
api GET /api/v1/stores "" key-a2.hdr
[[ $old_after == 401 && $code == 200 ]] || fail "R4 after revoke (old $old_after, new $code)"
pass 'R4: after explicit revoke old key 401, new key 200'
mv "$work/key-a2.hdr" "$work/key-a.hdr"

# --- recupero di chiavi orfane: cosa offre davvero l'API all'utente (nessuna ipotesi)
python3 -I - "$work/swagger.json" <<'PYEOF' > "$work/apikey-ops.txt"
import json, sys
d = json.load(open(sys.argv[1]))
for path, ops in sorted(d['paths'].items()):
    if '/api-keys' in path:
        for method, op in ops.items():
            if isinstance(op, dict):
                perms = ', '.join(p for s in op.get('security', []) for p in s.get('API_Key', [])) or '-'
                print(f"{method.upper()} {path} | dichiarato: {perms}")
PYEOF
sed 's/^/MATRIX: /' "$work/apikey-ops.txt"
if grep -q '^GET /api/v1/api-keys |' "$work/apikey-ops.txt"; then
    api GET /api/v1/api-keys "" basic-a.hdr
    printf 'INFO: GET /api/v1/api-keys with Basic -> %s\n' "$code"
else
    printf 'INFO: no endpoint to list own API keys in OpenAPI\n'
fi
api GET /api/v1/api-keys "" basic-a.hdr
[[ $code != 200 ]] || fail 'unexpected own-key listing (update the orphan-key plan)'
pass 'No listing of own keys: orphan keys cannot be discovered through the API'
if grep -q '^DELETE /api/v1/api-keys/{apiKeyId} |' "$work/apikey-ops.txt"; then
    api POST /api/v1/api-keys merchant-key.json basic-a.hdr
    [[ $code == 200 ]] || fail "orphan simulation ($code)"
    keyfile key-a3.hdr
    key3=$(sed 's/^Authorization: token //' "$work/key-a3.hdr" | tr -d '\n')
    api DELETE "/api/v1/api-keys/$key3" "" basic-a.hdr; revoke_basic=$code; unset key3
    revoke_error=$(json "[e.get('code') for e in (d if isinstance(d, list) else [d])]" 2>/dev/null || true)
    api GET /api/v1/stores "" key-a3.hdr
    printf 'INFO: DELETE /api/v1/api-keys/{apiKeyId} with Basic and the key value -> %s %s; key then -> %s\n' "$revoke_basic" "$revoke_error" "$code"
    # evidenza 2.4.7: la revoca per identificativo con Basic non trova la chiave appena creata; resta valida
    [[ $revoke_basic == 400 && $revoke_error == "['apikey-not-found']" && $code == 200 ]] || fail 'revoke-by-id behaviour changed (update the orphan-key plan)'
    api DELETE /api/v1/api-keys/current "" key-a3.hdr
    api GET /api/v1/stores "" key-a3.hdr
    [[ $code == 401 ]] || fail 'cleanup of the extra key'
    pass 'Revoke by id with Basic does not work (400 apikey-not-found); only the key itself can revoke it'
else
    fail 'DELETE /api/v1/api-keys/{apiKeyId} missing from OpenAPI (update the plan)'
fi

# --- riconciliazione per nome non affidabile
api POST /api/v1/stores store-a.json key-a.hdr
api GET /api/v1/stores "" key-a.hdr
[[ $(json "sum(1 for s in d if s['name'] == 'Negozio a')") == 2 ]] || fail 'duplicate names'
pass 'Same store name accepted twice: name is not a unique remote key (ambiguous reconciliation)'

# --- errori
printf 'Authorization: token %s\n' "$(openssl rand -hex 20)" > "$work/bad.hdr"
api GET /api/v1/stores "" bad.hdr
[[ $code == 401 ]] || fail "wrong key ($code)"
pass 'Unknown key: 401'
api GET /api/v1/stores/doesnotexist000000 "" key-a.hdr
[[ $code == 403 ]] || fail "unknown store ($code)"
pass 'Unknown store id: 403 (same as a foreign store, no existence oracle)'
api DELETE /api/v1/api-keys/current "" key-b.hdr
[[ $code == 200 ]] || fail "revoke ($code)"
api GET /api/v1/stores "" key-b.hdr
[[ $code == 401 ]] || fail "revoked key ($code)"
pass 'Key revoked by its holder: 401 afterwards'
docker compose -p "$BTCPAY_PROJECT" -f "$dir/compose.yml" stop btcpayserver >/dev/null 2>&1
api GET /api/v1/stores "" key-a.hdr
[[ $code == 000 ]] || fail "service down ($code)"
pass 'Service down: transport error, no HTTP response (worker must retry/reconcile)'
printf 'INFO: 429 responses on user creation: %d\n' "$throttled"
printf 'PASS %d B0 phase 2 checks (disposable regtest, no secrets printed)\n' "$checks"
