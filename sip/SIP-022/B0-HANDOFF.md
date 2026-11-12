# SIP-022 B0 - Handoff agente Napay

## Workspace

- Worktree orchestratore: `/var/www/blockchain-napoli/napay-worktrees/orchestrator-btcpay-b0`.
- Branch: `feature/btcpay-regtest-b0`, base `ecfa051`.
- Write set: `docker/btcpay-regtest/*` (compreso `tests/` e `tests/fixtures/`),
  `sip/SIP-022/B0-ESITI.md`, questo file.
- Nessuna modifica a gateway, `infra.yml`, `start-localhost.sh`, egress o Napay;
  nessun riavvio condiviso, nessuno stack persistente avviato, nessun reset
  persistente, nessun provisioning B1, nessun contatto con produzione o Internet.

## Commit

Prima consegna: `57f0f29` stack, `1fcd03c` test, `04c721a` documenti.

Correzioni della review di integrazione (B0-REVIEW-INTEGRAZIONE.md):

| Commit | Contenuto |
| --- | --- |
| `caa4769` | B0-RV1/RV2: `local.sh` confina lo stato e rifiuta reti incompatibili |
| `45038bd` | test `filesystem.sh` (docker finto, sentinelle) |
| `83536ed` | B0-RV3: rete edge con subnet fissa verificata |
| `bf70527` | test `topology.sh` della topologia proposta (controfigure locali) |
| `f6be0a8` | B0-RV4: `isolated.sh` con controlli positivi e prova TCP sull'IP RPC |
| `bc4d756` | blocco del backend nel gateway anche sui siti con `handle` |

## Correzioni

### B0-RV1 - percorsi e file privati

- `BTCPAY_LOCAL_STATE` deve essere già canonico (`realpath -m` uguale al valore):
  rifiutati `..`, `.`, slash finale, symlink negli antenati o sulla cartella.
- Vietati: dentro o antenato del checkout corrente e del checkout principale
  (ricavato da `git rev-parse --git-common-dir`, copre i worktree).
- La cartella la crea solo `up`; `status`, `stop` e `reset` non creano nulla.
  Dopo la creazione: ricontrollo canonico e proprietario, `chmod 700`.
- Lock con `flock` sul descrittore della cartella: nessun `control.lock`
  creato o troncato.
- Prima di aprire un file: niente symlink (anche pendenti), file regolare,
  proprietario, un solo link fisico, nessun permesso per gruppo/altri.
  Altrimenti stop senza toccarlo.
- Creazione di `.gitignore` e `regtest.env`: file temporaneo nuovo e link
  fisico verso il nome finale, che fallisce se il nome esiste (anche come
  symlink pendente): niente sovrascritture, contenuto completo o assente.
- `.gitignore` deve contenere la riga `*`.

### B0-RV2 - rete esistente

`up` accetta una rete `BTCPAY_EDGE_NETWORK` già esistente solo se bridge
interna, etichetta `napay.btcpay-regtest=edge` e subnet attesa; altrimenti
si ferma senza modificarla e senza avviare lo stack. Stessi controlli nella
patch a `start-localhost.sh` (sotto) per entrambe le reti.

### B0-RV3 - reti backend e client separate

Topologia della review, con un'aggiunta:

- `btcpay_regtest_edge` (interna, subnet fissa `10.252.0.0/24`): solo gateway
  e backend BTCPay; nessun alias del gateway su questa rete.
- `btcpay_regtest_client` (interna): solo gateway (alias `btcpay.local`) e
  proxy di uscita Napay. Il proxy non entra mai nella rete edge.
- Napay web resta sulle sue reti: arriva a BTCPay solo con CONNECT
  `btcpay.local:443` tramite il proxy, con verifica della CA locale.
- **Aggiunta:** il backend, stando sulla rete del gateway, poteva chiamare il
  gateway e raggiungere `napay.local`, `wallet.local`, `pos.localhost`. Lo
  snippet `no_btcpay_backend` rifiuta la subnet edge su ogni sito.
  Va scritto come `handle @btcpay_backend { abort }`: un `abort` semplice
  viene ordinato da Caddy dopo i blocchi `handle` e su wallet.caddy verrebbe
  scavalcato (verificato con `caddy adapt` e con il test). Con la patch, su
  tutti i 9 siti adattati prima del blocco ci sono solo intestazioni o
  redirect 301 verso HTTPS: nessun inoltro.
- Il futuro webhook BTCPay -> Napay richiederà un'eccezione esplicita, da
  decidere in fase successiva (oggi bloccato).

### B0-RV4 - test discriminanti

`isolated.sh` (stack reale) e `topology.sh` (topologia proposta) usano solo
sentinelle locali e hanno un controllo positivo per ogni negativo:

- prerequisiti espliciti; curl del client verificato prima delle sonde;
- uscita: sentinella su bridge normale raggiunta da quella rete, irraggiungibile
  (curl 7/28) dalle reti regtest ed edge;
- RPC: POST all'IP reale del nodo = 401 dalla rete regtest; dalla edge la
  connessione deve fallire (curl 7/28, nessun codice HTTP); un 401 fa fallire;
- reti di ogni container verificate una per una;
- proxy: backend senza accesso a nessun indirizzo effettivo del proxy, su
  qualunque rete sia collegato; il test fallisce se il proxy viene messo
  anche sulla edge (vecchia patch) o se manca il blocco nel gateway.

## Test eseguiti (2026-11-12)

- `tests/filesystem.sh`: 27 PASS, senza Docker reale. Sul `local.sh` della
  prima consegna fallisce al primo caso (percorso con `..`).
- `tests/topology.sh`: 11 PASS. Prove di discriminazione: fallisce con il proxy
  sulla edge e con `abort` semplice nel gateway.
- `tests/isolated.sh`: 14 PASS, nessun container, rete o volume residuo.
- Patch: `caddy validate` sulla configurazione completa del gateway patchata
  = valida; `caddy adapt` = blocco per primo su tutti i siti; `bash -n` sul
  launcher patchato; Squid patchato identico (salvo commenti) al fixture testato.
- Non eseguiti: patch applicate ai file reali, gateway reale, fase 2 via TLS.

## Patch proposte (NON applicate)

Basi: orchestratore `feature/v2-yii2-php83-docker` `c63fad0`, Napay
`feature/v2-yii2-php83-docker` `2bc89049`. Sostituiscono le patch della prima
consegna.

### Orchestratore: gateway, reti, launcher

```diff
diff -ruN a/docker/compose/infra.yml b/docker/compose/infra.yml
--- a/docker/compose/infra.yml	2026-11-12 15:03:04.936427250 +0100
+++ b/docker/compose/infra.yml	2026-11-12 15:04:55.799253523 +0100
@@ -21,6 +21,11 @@
       # rete interna del server POS (SIP-021): il POS raggiunge napay solo dal gateway, in HTTPS verificato
       pos_local_browser:
         aliases: [napay.local]
+      # SIP-022 B0: edge = solo gateway e backend BTCPay regtest (nessun alias: il backend non deve trovare servizi)
+      btcpay_regtest_edge: {}
+      # SIP-022 B0: client = solo gateway e proxy di uscita Napay, che raggiunge https://btcpay.local
+      btcpay_regtest_client:
+        aliases: [btcpay.local]
 
   mysql-main:
     image: mysql:8.0
@@ -115,6 +120,13 @@
   pos_local_browser:
     name: pos_local_browser
     external: true
+  # create da start-localhost.sh (interne, controllate); edge anche da docker/btcpay-regtest/local.sh
+  btcpay_regtest_edge:
+    name: btcpay_regtest_edge
+    external: true
+  btcpay_regtest_client:
+    name: btcpay_regtest_client
+    external: true
 
 volumes:
   mysql_data:
diff -ruN a/docker/gateway/Caddyfile b/docker/gateway/Caddyfile
--- a/docker/gateway/Caddyfile	2026-11-12 15:03:04.916427099 +0100
+++ b/docker/gateway/Caddyfile	2026-11-12 15:05:08.067343853 +0100
@@ -4,7 +4,17 @@
     admin off
 }
 
+# SIP-022 B0: richieste dal backend BTCPay regtest (rete btcpay_regtest_edge, subnet fissa) rifiutate su ogni sito.
+# handle (non abort semplice): Caddy lo valuta prima dei blocchi handle dei siti, che altrimenti lo scavalcano.
+(no_btcpay_backend) {
+    @btcpay_backend remote_ip 10.252.0.0/24
+    handle @btcpay_backend {
+        abort
+    }
+}
+
 :80 {
+    import no_btcpay_backend
     redir https://napay.local{uri} permanent
 }
 
diff -ruN a/docker/gateway/conf.d/btcpay.caddy b/docker/gateway/conf.d/btcpay.caddy
--- a/docker/gateway/conf.d/btcpay.caddy	1970-01-01 01:00:00.000000000 +0100
+++ b/docker/gateway/conf.d/btcpay.caddy	2026-11-12 15:04:55.799253523 +0100
@@ -0,0 +1,8 @@
+# BTCPay regtest locale (SIP-022 B0): solo test di provisioning, bitcoin finti. Stack docker/btcpay-regtest.
+# Raggiunto solo dal proxy di uscita Napay sulla rete btcpay_regtest_client; backend sulla rete btcpay_regtest_edge.
+https://btcpay.local {
+    import no_btcpay_backend
+    header X-Content-Type-Options nosniff
+    header Referrer-Policy no-referrer
+    reverse_proxy btcpay-regtest:49392
+}
diff -ruN a/docker/gateway/conf.d/napay.caddy b/docker/gateway/conf.d/napay.caddy
--- a/docker/gateway/conf.d/napay.caddy	2026-11-12 15:03:04.923427152 +0100
+++ b/docker/gateway/conf.d/napay.caddy	2026-11-12 15:04:55.799253523 +0100
@@ -1,9 +1,11 @@
 # Backoffice napay: sandbox locale napay/docker/local (web senza porte, rete interna napay_local_browser).
 http://napay.local, http://napay.test, http://localhost, https://napay.test, https://localhost {
+    import no_btcpay_backend
     redir https://napay.local{uri} permanent
 }
 
 https://napay.local {
+    import no_btcpay_backend
     header X-Content-Type-Options nosniff
     header Referrer-Policy no-referrer
     # API server-to-server dei POS (SIP-021): solo dalla rete interna pos_local_browser
diff -ruN a/docker/gateway/conf.d/pos.caddy b/docker/gateway/conf.d/pos.caddy
--- a/docker/gateway/conf.d/pos.caddy	2026-11-12 15:03:04.927427182 +0100
+++ b/docker/gateway/conf.d/pos.caddy	2026-11-12 15:04:55.799253523 +0100
@@ -1,9 +1,11 @@
 # POS Yii2 preview: separate app, no legacy document root or payment credentials.
 http://pos.localhost {
+    import no_btcpay_backend
     redir https://pos.localhost{uri} permanent
 }
 
 https://pos.localhost {
+    import no_btcpay_backend
     header {
         X-Content-Type-Options nosniff
         Referrer-Policy no-referrer
diff -ruN a/docker/gateway/conf.d/wallet.caddy b/docker/gateway/conf.d/wallet.caddy
--- a/docker/gateway/conf.d/wallet.caddy	2026-11-12 15:03:04.932427219 +0100
+++ b/docker/gateway/conf.d/wallet.caddy	2026-11-12 15:04:55.799253523 +0100
@@ -1,9 +1,11 @@
 # Wallet poawallet: HTTP app + WebSocket notifiche.
 http://wallet.local, http://poawallet.local, http://wallet.test {
+    import no_btcpay_backend
     redir https://{host}{uri} permanent
 }
 
 https://wallet.local, https://poawallet.local, https://wallet.test {
+    import no_btcpay_backend
     handle /ws-notify {
         reverse_proxy ws-notify:14800
     }
diff -ruN a/start-localhost.sh b/start-localhost.sh
--- a/start-localhost.sh	2026-11-12 15:03:04.942427295 +0100
+++ b/start-localhost.sh	2026-11-12 15:04:55.799253523 +0100
@@ -36,6 +36,11 @@
 # rete interna del server POS: subnet fissa, l'API /api/pos/* è accettata dal gateway solo da qui (SIP-021)
 POS_NETWORK=pos_local_browser
 POS_SUBNET=10.251.0.0/24
+# BTCPay regtest (SIP-022 B0): edge = gateway <-> backend (subnet fissa, rifiutata dal gateway sugli altri siti),
+# client = gateway <-> proxy di uscita Napay. Reti separate: il backend non raggiunge mai il proxy.
+BTCPAY_EDGE_NETWORK=btcpay_regtest_edge
+BTCPAY_EDGE_SUBNET=10.252.0.0/24
+BTCPAY_CLIENT_NETWORK=btcpay_regtest_client
 
 step 'Prerequisiti'
 docker info >/dev/null 2>&1 || fail 'Docker non attivo o non accessibile al tuo utente.'
@@ -69,6 +74,19 @@
   || docker network create --internal --subnet "$POS_SUBNET" --label napay.service=pos-local "$POS_NETWORK" >/dev/null
 [[ "$(docker network inspect "$POS_NETWORK" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')" == "$POS_SUBNET" ]] \
   || fail "la rete $POS_NETWORK esiste con una subnet diversa da $POS_SUBNET."
+# rete esistente accettata solo se bridge interna con etichetta e subnet attese; mai modificata
+btcpay_network() { # nome etichetta [subnet]
+  local name=$1 label=$2 subnet=${3:-} props
+  if docker network inspect "$name" >/dev/null 2>&1; then
+    props=$(docker network inspect -f '{{.Internal}} {{.Driver}} {{index .Labels "napay.btcpay-regtest"}} {{range .IPAM.Config}}{{.Subnet}}{{end}}' "$name")
+    [[ $props == "true bridge $label "* && ( -z $subnet || $props == *" $subnet" ) ]] \
+      || fail "la rete $name esiste ma non e' la bridge interna attesa (napay.btcpay-regtest=$label ${subnet}): non modificata."
+  else
+    docker network create --internal --driver bridge ${subnet:+--subnet "$subnet"} --label "napay.btcpay-regtest=$label" "$name" >/dev/null
+  fi
+}
+btcpay_network "$BTCPAY_EDGE_NETWORK" edge "$BTCPAY_EDGE_SUBNET"
+btcpay_network "$BTCPAY_CLIENT_NETWORK" client
 compose config --quiet || fail 'configurazione docker compose non valida.'
 
 if $BUILD; then
```

### Napay: proxy di uscita

```diff
diff -ruN na/docker/egress/squid.conf nb/docker/egress/squid.conf
--- na/docker/egress/squid.conf	2026-11-12 15:03:04.949427348 +0100
+++ nb/docker/egress/squid.conf	2026-11-12 15:04:55.799253523 +0100
@@ -2,6 +2,8 @@
 # Solo tunnel HTTPS: nessun proxy HTTP in chiaro, nessuna cache, nessun header che riveli l'origine.
 http_port 3128
 acl payment_hosts dstdomain api-m.paypal.com api-m.sandbox.paypal.com btcpayserver.napoliblockchain.it
+# BTCPay regtest locale (SIP-022 B0): solo il gateway, host esatto, porta 443
+acl btcpay_regtest dstdomain btcpay.local
 acl internal src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
 acl SSL_ports port 443
 acl CONNECT method CONNECT
@@ -9,6 +11,7 @@
 http_access deny !CONNECT
 http_access deny !SSL_ports
 http_access allow payment_hosts
+http_access allow btcpay_regtest
 http_access deny all
 cache deny all
 via off
diff -ruN na/docker/local/compose.yml nb/docker/local/compose.yml
--- na/docker/local/compose.yml	2026-11-12 15:03:04.953427378 +0100
+++ nb/docker/local/compose.yml	2026-11-12 15:04:55.799253523 +0100
@@ -37,7 +37,8 @@
       - ALL
     security_opt:
       - no-new-privileges:true
-    networks: [egress, internet]
+    # btcpay_regtest_client: solo gateway e questo proxy (https://btcpay.local), mai la rete del backend BTCPay
+    networks: [egress, internet, btcpay_regtest_client]
     healthcheck:
       test: ["CMD", "nc", "-z", "127.0.0.1", "3128"]
       interval: 10s
@@ -53,6 +54,9 @@
   napay_local_browser:
     name: napay_local_browser
     external: true
+  btcpay_regtest_client:
+    name: btcpay_regtest_client
+    external: true
 volumes:
   local_runtime:
   local_assets:
```

## Da decidere al master (fase 2)

- CA locale per il futuro worker (file CA montato, `CURLOPT_CAINFO`), senza
  disattivare la verifica.
- Accesso dal browser a `btcpay.local` solo se serve (`/etc/hosts`).
- URL generati da BTCPay dietro reverse proxy (`X-Forwarded-Proto`) da
  verificare in fase 2, senza allargare i proxy fidati.
- Eventuale eccezione per i webhook BTCPay -> Napay.
