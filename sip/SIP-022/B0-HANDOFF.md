# SIP-022 B0 - Handoff agente Napay

## Workspace

- Worktree orchestratore: `/var/www/blockchain-napoli/napay-worktrees/orchestrator-btcpay-b0`.
- Branch: `feature/btcpay-regtest-b0`, base `ecfa051`.
- Solo file assegnati: `docker/btcpay-regtest/{compose.yml,local.sh,.env.example,README.md}`,
  `docker/btcpay-regtest/tests/isolated.sh`, `sip/SIP-022/B0-ESITI.md`, questo file.
- Nessuna modifica a gateway, `infra.yml`, `start-localhost.sh`, egress o Napay;
  nessun riavvio condiviso; nessun provisioning B1; nessuna chiave di produzione.

## Stato

- Fase 1 (stack): pronta. `tests/isolated.sh` **11 PASS**, nessuna risorsa
  residua (progetto, rete e cartella privata temporanei). Esiti in
  [B0-ESITI.md](B0-ESITI.md).
- Lo stack persistente **non** è stato avviato: lo avvia l'utente o il master
  con `local.sh up` dopo l'integrazione delle patch.
- Fase 2 (verifiche via TLS): bloccata fino all'integrazione delle patch sotto.

## Punti della review master

1. Tag verificati sul registry, fissati per digest (B0-ESITI).
2. OpenAPI: risponde 401 senza credenziali; si scarica in fase 2 con admin di
   test. Matrice endpoint/permesso/esito predisposta in B0-ESITI.
3. Utente con password casuale senza invito: verifica di fase 2 (punto 3).
4. Riconciliazione: in fase 2 si registra che nome/email non sono vincoli remoti;
   risultati multipli = ambiguo, nessun POST automatico.
5. TLS: Napay/worker solo tramite proxy a `https://btcpay.local:443`, CA locale;
   allowlist esatta (dominio `btcpay.local`, porta 443 già imposta da Squid).
6. Stack opt-in, nessuna porta host, rete distinta da POS e DB Napay,
   healthcheck con tempi massimi, volumi nominati conservati agli stop,
   reset distruttivo solo con `reset --yes`.

## Patch proposte (NON applicate)

Verificate su copie: `caddy validate` sulla configurazione del gateway con
`btcpay.caddy` = configurazione valida; YAML dei compose letti correttamente;
`bash -n` su `start-localhost.sh`.

### Orchestratore: gateway, rete, avvio

Il gateway entra nella rete `btcpay_regtest_edge` con alias `btcpay.local`
(raggiungibile dal proxy di uscita) e pubblica il sito con la CA locale.
`start-localhost.sh` crea la rete se manca (`local.sh` fa lo stesso).

```diff
diff -ruN a/docker/compose/infra.yml b/docker/compose/infra.yml
--- a/docker/compose/infra.yml	2026-11-12 14:23:57.107407867 +0100
+++ b/docker/compose/infra.yml	2026-11-12 14:23:57.138407998 +0100
@@ -21,6 +21,9 @@
       # rete interna del server POS (SIP-021): il POS raggiunge napay solo dal gateway, in HTTPS verificato
       pos_local_browser:
         aliases: [napay.local]
+      # BTCPay regtest (SIP-022 B0): rete interna creata da start-localhost.sh / docker/btcpay-regtest/local.sh
+      btcpay_regtest_edge:
+        aliases: [btcpay.local]
 
   mysql-main:
     image: mysql:8.0
@@ -115,6 +118,9 @@
   pos_local_browser:
     name: pos_local_browser
     external: true
+  btcpay_regtest_edge:
+    name: btcpay_regtest_edge
+    external: true
 
 volumes:
   mysql_data:
diff -ruN a/docker/gateway/conf.d/btcpay.caddy b/docker/gateway/conf.d/btcpay.caddy
--- a/docker/gateway/conf.d/btcpay.caddy	1970-01-01 01:00:00.000000000 +0100
+++ b/docker/gateway/conf.d/btcpay.caddy	2026-11-12 14:23:57.118407913 +0100
@@ -0,0 +1,7 @@
+# BTCPay regtest locale (SIP-022 B0): solo test di provisioning, bitcoin finti. Stack docker/btcpay-regtest.
+# Raggiungibile da Napay solo tramite il proxy di uscita (allowlist btcpay.local:443), certificato della CA locale.
+https://btcpay.local {
+    header X-Content-Type-Options nosniff
+    header Referrer-Policy no-referrer
+    reverse_proxy btcpay-regtest:49392
+}
diff -ruN a/start-localhost.sh b/start-localhost.sh
--- a/start-localhost.sh	2026-11-12 14:23:57.109407875 +0100
+++ b/start-localhost.sh	2026-11-12 14:23:57.138407998 +0100
@@ -36,6 +36,8 @@
 # rete interna del server POS: subnet fissa, l'API /api/pos/* è accettata dal gateway solo da qui (SIP-021)
 POS_NETWORK=pos_local_browser
 POS_SUBNET=10.251.0.0/24
+# rete interna gateway <-> BTCPay regtest (SIP-022 B0); lo stack regtest si avvia a parte
+BTCPAY_EDGE_NETWORK=btcpay_regtest_edge
 
 step 'Prerequisiti'
 docker info >/dev/null 2>&1 || fail 'Docker non attivo o non accessibile al tuo utente.'
@@ -67,6 +69,8 @@
   || docker network create --internal --label napay.service=browser-local "$LOCAL_NETWORK" >/dev/null
 docker network inspect "$POS_NETWORK" >/dev/null 2>&1 \
   || docker network create --internal --subnet "$POS_SUBNET" --label napay.service=pos-local "$POS_NETWORK" >/dev/null
+docker network inspect "$BTCPAY_EDGE_NETWORK" >/dev/null 2>&1 \
+  || docker network create --internal --label napay.btcpay-regtest=edge "$BTCPAY_EDGE_NETWORK" >/dev/null
 [[ "$(docker network inspect "$POS_NETWORK" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')" == "$POS_SUBNET" ]] \
   || fail "la rete $POS_NETWORK esiste con una subnet diversa da $POS_SUBNET."
 compose config --quiet || fail 'configurazione docker compose non valida.'
```

### Napay: proxy di uscita

Squid ammette `btcpay.local` (solo CONNECT su 443, come gli altri host); il
container egress entra nella rete `btcpay_regtest_edge` per risolvere il
gateway. Il web Napay resta senza uscita diretta.

```diff
diff -ruN na/docker/egress/squid.conf nb/docker/egress/squid.conf
--- na/docker/egress/squid.conf	2026-11-12 14:23:57.112407888 +0100
+++ nb/docker/egress/squid.conf	2026-11-12 14:23:57.138407998 +0100
@@ -2,6 +2,8 @@
 # Solo tunnel HTTPS: nessun proxy HTTP in chiaro, nessuna cache, nessun header che riveli l'origine.
 http_port 3128
 acl payment_hosts dstdomain api-m.paypal.com api-m.sandbox.paypal.com btcpayserver.napoliblockchain.it
+# BTCPay regtest locale (SIP-022 B0), tramite il gateway con CA locale
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
--- na/docker/local/compose.yml	2026-11-12 14:23:57.114407896 +0100
+++ nb/docker/local/compose.yml	2026-11-12 14:23:57.138407998 +0100
@@ -37,7 +37,8 @@
       - ALL
     security_opt:
       - no-new-privileges:true
-    networks: [egress, internet]
+    # btcpay_regtest_edge: solo per raggiungere https://btcpay.local (gateway), SIP-022 B0
+    networks: [egress, internet, btcpay_regtest_edge]
     healthcheck:
       test: ["CMD", "nc", "-z", "127.0.0.1", "3128"]
       interval: 10s
@@ -53,6 +54,9 @@
   napay_local_browser:
     name: napay_local_browser
     external: true
+  btcpay_regtest_edge:
+    name: btcpay_regtest_edge
+    external: true
 volumes:
   local_runtime:
   local_assets:
```

### Da decidere al master (non incluso nelle patch)

- CA locale per il futuro worker/Napay verso `btcpay.local` (file CA montato e
  usato come `CURLOPT_CAINFO`), senza disattivare la verifica.
- Accesso dal browser all'interfaccia regtest: solo se serve, riga
  `127.0.0.1 btcpay.local` in `/etc/hosts`.
- BTCPay dietro reverse proxy: verificare in fase 2 gli URL generati
  (`X-Forwarded-Proto`), senza allargare i proxy fidati.

## Test

- `bash docker/btcpay-regtest/tests/isolated.sh`: 11 PASS (2026-11-12).
- Non eseguiti: fase 2 (serve il gateway integrato), nessun test grafico.
