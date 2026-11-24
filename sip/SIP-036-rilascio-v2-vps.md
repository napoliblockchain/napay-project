# SIP-036 - Rilascio della v2 sulla VPS e passaggio dalla v1

- Stato: IN_PROGRESS
- Area: Rilascio / DevOps
- Repo: orchestratore, `napay`, `pos`, `poawallet`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-23 (richiesta utente: arrivare a qualcosa di pubblicabile)

## Contesto
Le funzioni v2 (backoffice, POS, wallet, BTCPay, import dalla v1) sono
testate in sandbox e su stack usa-e-getta, ma per la VPS esiste solo il
rilascio del wallet (`deploy-wallet.sh`). La composizione dell'orchestratore
punta ancora al POS legacy e all'immagine di sviluppo di Napay. Il POS v2
accetta solo la modalità "preview" (chain di test). Non c'è una procedura
del passaggio scritta e provata.

## Parti

| Parte | Cosa | Chi |
| --- | --- | --- |
| A | Napay in produzione: immagine versionata, web, cron, worker BTCPay, bootstrap/import, script di rilascio con controllo, ritorno alla versione precedente | CLA (master) |
| B | POS v2 in produzione: modalità produzione nell'app, composizione e script di rilascio | COD ([incarico](SIP-036/PROMPT-AGENTE-COD.md)) |
| C | Orchestratore: gateway e certificati dei domini reali, reti, backup del database v2 | CLA |
| D | Procedura del passaggio (fermo v1 1-2 ore, variabili, logo, webhook, ritorno alla v1) | CLA |
| E | Prova generale dell'import su copia fresca del DB di produzione | CLA + utente |

## Regole
- Segreti solo in file privati 0600 fuori dai repository; nessun valore nei
  log o nell'output; nessuna porta pubblicata oltre al gateway.
- Ogni script ha una modalità di solo controllo che non costruisce e non avvia.
- Migration automatiche al rilascio; se falliscono resta in servizio la
  versione precedente.
- Nessun rilascio sulla VPS senza ok esplicito dell'utente.

## Criteri di accettazione
- Rilascio ripetibile da una cartella pulita con il solo file env privato.
- Prova generale: import completo e riconciliazione verdi sulla copia fresca.
- Procedura del passaggio scritta, con tempi e passi di ritorno alla v1.

## Parte A - Napay in produzione (piano, 2026-11-23)

Base esistente: `napay/docker/up.sh` (controllo preliminare, utenti DB
separati, ripristino di `napay_v2`, import v1 da `LEGACY_DB_DSN`, verbali in
sola lettura). Topologia e passaggio: `architettura-produzione.md` e
`guida-vps-app.md` (cartella documents, parte 4 in attesa di questa parte).

- A1. Uscita verso la chain TTS (VPS C, `poa.jamprojects.it`): oggi
  `TtsChain` chiama l'RPC direttamente (in sandbox la chain è sulla stessa
  rete). In produzione passa dal proxy di uscita come PayPal e BTCPay: RPC
  HTTPS = tramite proxy se configurato, RPC HTTP interno = diretto;
  `poa.jamprojects.it` aggiunto all'allowlist.
- A2. Overlay di produzione: codice in sola lettura, runtime e asset in
  volumi, nessuna porta sull'host, web sulla rete del gateway (nome da env),
  proxy di uscita, worker BTCPay e cron col ponte quando i segreti ci sono.
- A3. `docker/deploy.sh env-file [--check]`: controllo completo senza avvio;
  backup del database prima di ogni rilascio (le migration non si annullano:
  il ritorno indietro è il ripristino del backup), rilascio, attesa dello
  stato sano, riepilogo dell'import.
- A4. Gateway con i domini reali (`napay.napoliblockchain.it`,
  `pos.napoliblockchain.it`) e Let's Encrypt; webhook BTCPay dal
  server della VPS B accettati solo su `/api/btcpay/v1/store-webhook` e
  `/api/btcpay/v1/webhook`.

Posta SMTP (decisa 2026-11-24): inoltro TCP dedicato, vedi Avanzamento.

## Avanzamento

- 2026-11-23 A1 FATTO (napay `73d26e2c`): RPC HTTPS della chain TTS dal proxy
  di uscita, `poa.jamprojects.it` in allowlist; test TTS 67 + 30 + 20.
- 2026-11-23 A2/A3 FATTI (napay `4a66a7eb`, `9e7fd59f`, `b2aa825e`):
  `docker-compose.prod.yml` e `docker/deploy.sh env-file [--check]`; nuove
  variabili `NAPAY_GATEWAY_NETWORK`, `NAPAY_TRUSTED_PROXIES`,
  `NAPAY_BACKUP_DIR`. Test: preflight 19 (modello compose: niente porte, codice
  in sola lettura, internet solo al proxy, immagini del commit), `up.sh` 26,
  collaudo reale 6 (prima installazione, web solo dalla rete del gateway,
  backup gzip 0600 al secondo rilascio, nessun segreto nell'output).
  Non ancora provati nel collaudo: overlay del worker BTCPay in produzione,
  import v1 da `LEGACY_DB_DSN` dentro `deploy.sh` (provato da `bootstrap.sh`).
- 2026-11-23 A4/C gateway FATTO (orchestratore `7703278`):
  `docker/gateway/prod/Caddyfile`, `docker-compose.prod.yml`,
  `deploy-gateway.sh env-file [--check]`; reti interne napay e POS con subnet
  fisse (`NAPAY_GATEWAY_SUBNET` = `NAPAY_TRUSTED_PROXIES` di napay). Test 14:
  rifiuti del controllo, instradamento per dominio, `/api/pos` solo dalla rete
  dei POS, webhook BTCPay solo dall'IP di BTCPay, HSTS e intestazioni,
  redirect HTTP.
- Ordine di rilascio: `deploy-gateway.sh`, napay `docker/deploy.sh`, POS,
  `deploy-wallet.sh`.
- 2026-11-23 D in bozza: parte 4 di `guida-vps-app.md` (documents) scritta
  con gli script di rilascio: codice per commit, cartella privata, MySQL
  temporaneo con i soli schemi `napay` e `napay_v2`, file v1 riuniti (verbali in
  radice, logo in `custom/`), gateway, napay senza import, import con
  `LEGACY_*` (backup automatico prima), POS, wallet, collaudo, chiusura.
- 2026-11-23 B FATTA (COD, [handoff](SIP-036/HANDOFF-COD.md)), integrata dal
  master (pos fast-forward a `8d4aec0`): modalità produzione, compose e
  `pos/v2/docker/deploy.sh env-file [--check]` con ritorno all'immagine
  precedente. Test dal checkout principale: unit 398, deploy 31; POS della
  sandbox ricostruito, ancora in preview. Variabili nella procedura del
  passaggio (incluso `POS_API_CLIENT_KEYS_SHA256` di napay).
- 2026-11-24 SMTP FATTO (napay `cca4ce51`): stesso server della v1
  (`authsmtp.securemail.pro:465`, TLS); con `MAIL_TRANSPORT=smtp` il rilascio
  aggiunge un inoltro TCP dedicato verso il solo server di posta, alias del suo
  nome sulla rete egress; TLS e credenziali tra Napay e il server. Test 4
  (reti senza internet, CA di test) e controllo preliminare 22.
- 2026-11-24 backup primo livello FATTO (napay `13ce793d`, orchestratore
  `backup-daily.sh`, `docker/systemd/napay-backup.{service,timer}`): ogni notte
  database Napay e wallet sul filesystem della VPS, gzip 0600, file completi o
  niente, 14 giorni (solo i giornalieri; i backup dei rilasci restano). Collaudo
  10 con ripristino reale. Copia fuori macchina: storage Contabo se il costo
  viene approvato (decisione utente), prelevata dalla cartella dei backup.
- 2026-11-24 dati reali della VPS A (dump di sicurezza prima delle patch): database
  `npay` (v1; non `napay` come nella copia di ottobre), `wordpress`, `phpmyadmin`,
  `mysql`; **nessun `napay_v2`**. Conseguenze: `LEGACY_DB_DSN` con `dbname=npay`
  (procedura corretta); il primo avvio della v2 deve poter partire da vuoto
  (schema dalle migration, dati solo dall'import v1) invece che dal dataset
  `napay_v2` (A5, da fare); WordPress e phpMyAdmin sulla stessa Apache: da
  censire (domini serviti) prima di sostituire Apache con il gateway.
- Aperti: A5 primo avvio da vuoto; WordPress/phpMyAdmin sulla VPS A; copia fuori
  macchina (in attesa del costo); parte E
  (prova generale della procedura su copia fresca dei dati).
