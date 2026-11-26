# SIP-036 parte B - Handoff COD a CLA

Data: 2026-11-23. Stato: PRONTO PER REVIEW, non integrato, nessun deploy VPS.

## Branch e commit

- Repo: POS; worktree `/var/www/blockchain-napoli/napay-worktrees/pos-deploy`.
- Branch: `feature/v2-pos-deploy`; base `50b9b6d`; HEAD `8d4aec0`.
- Worktree pulita; modifiche solo sotto `v2/`. `docker/local.sh` invariato.
- Nessun edit a Napay, wallet, gateway o composizioni dell'orchestratore.
- Questo handoff e volutamente non committato nell'orchestratore.

Commit in ordine di integrazione:

1. `fb0cd6a` - Modalita production, backend HTTPS configurabile, proxy validati, CA di sistema/supporto CA aggiuntiva, testi non-demo.
2. `3bd56ee` - Immagine production, compose separato, deploy con controllo e rollback, documentazione.
3. `bf3d103` - Test configurazione, TLS, release e rollback; runner unit offline.
4. `1820ca3` - Fixture offline con dipendenze cached verificate contro lock.
5. `9413d02` - Asserzione zero porte compatibile con rappresentazione Docker null/oggetto vuoto.
6. `e7a1739` - Diagnostica fixture per numero riga, senza stampare comandi/valori.
7. `03f5a0a` - Permessi sorgenti fixture leggibili da Apache; timeout fixture45s.
8. `28c3d2c` - Note CA privata gateway, ownership Docker e limiti prova offline.
9. `8d4aec0` - Avvio reale entrypoint production senza CA aggiuntiva.

## Implementazione

- Nuovo `components/RuntimeConfig.php`: URL HTTPS con percorso esatto `/api/pos/v1`, senza userinfo/query/fragment; proxy IPv4 CIDR1..32, massimo16, niente wildcard/all-addresses.
- `config/web.php`: solo preview/production; proxy da env, default sandbox invariato; API configurabile; CA assente in production significa trust store sistema, non TLS disabilitato.
- `NapayLoginClient.php`: controllo configurazione comune alle chiamate esistenti; verifica TLS obbligatoria, no redirect, timeout e limiti risposta invariati; bearer sempre server-side.
- Health comunica modalita reale senza dettagli interni. Layout senza avviso chain demo in production; traduzione italiana presente.
- Guardia404 di `payment/request` e condizione del pulsante erano gia presenti: riutilizzate, non duplicate, coperte dai nuovi test.
- Dockerfile con target production senza tests e target finale preview, per conservare il comportamento locale preesistente. PHP8.3.36 e Composer2.10.3 invariati.
- Compose production: immagine dal commit, nessuna porta host o bind sorgenti, runtime privato persistente, root read-only, secret client, tmpfs segreti, rete esterna parametrica, alias `pos-v2-web`, healthcheck.
- Overlay CA facoltativo: secret copiato in tmpfs privato per uid33; senza CA aggiuntiva entrypoint production funziona con trust store sistema. Preview richiede ancora CA locale.
- `docker/deploy.sh env-file [--check]`: parser env senza source/eval; allowlist impostazioni, proprietario/0600 e directory0700, niente symlink o percorsi dentro repo applicativi; chiave validata; compose validato.
- `--check` non costruisce, non avvia e non crea stato. Release richiede checkout committed/pulito, lock privato, build taggata commit, attesa health. Fallimento build lascia servizio precedente; fallimento avvio ripristina esatto image ID precedente e ne verifica health. Primo rilascio fallito rimuove solo servizio fallito.
- Output a messaggi fissi e revisioni; log privati, nessuna stampa env/segreti.
- Configurazione esempio: `v2/docker/production.env.example`; guida `v2/docs/PRODUCTION.md`.

## Variabili produzione (solo nomi)

Obbligatorie nel file env:
`POS_MODE`, `COOKIE_VALIDATION_KEY`, `NAPAY_API_BASE_URL`,
`POS_TRUSTED_PROXIES`, `NAPAY_CLIENT_KEY_SOURCE`, `POS_RUNTIME_DIR`,
`POS_GATEWAY_NETWORK`.

Facoltative:
`NAPAY_CA_SOURCE`, `POS_LABEL`, `POS_COMPOSE_PROJECT`,
`POS_DEPLOY_WAIT_SECONDS`.

Derivate dallo script, non ammesse nel file privato:
`POS_ENV_FILE`, `POS_RELEASE_IMAGE`.

Imposte dal compose per il processo applicativo:
`NAPAY_POS_CLIENT_KEY_FILE`, `NAPAY_CA_FILE`.

Solo controllo build del processo chiamante: `POS_BUILD_NETWORK`.

Il gateway del master usa `POS_GATEWAY_SUBNET`: trasferirne il CIDR nel
`POS_TRUSTED_PROXIES` del POS. Non aggiungere il nome subnet al file POS:
il parser rifiuta impostazioni sconosciute.

## Test realmente eseguiti

- `bash v2/tests/docker/unit.sh`: PASS398 controlli PHP complessivi:
  config13, amount21, login37, logout18, catalog37, opening44, payment155,
  PWA44, production29.
- Nello stesso runner: controllo struttura OpenAPI (45 riferimenti locali
  risolti) e PASS7 controlli percorsi privati Node. Nessun backend contattato.
- `bash v2/tests/docker/production-deploy.sh`: PASS31 controlli deploy,
  piu3 probe TLS reali. Testato --check negativo/positivo, input mancanti o
  invalidi, ownership, permessi, symlink, percorsi repo, chiavi/certificati,
  interpolazioni e nessun leak canary nell'output.
- Immagine production costruita e avviata, health verde, zero porte host,
  root read-only, nessuna directory tests nell'immagine, HTTP request test404.
- TLS reale su rete interna usa-e-getta: CA aggiuntiva valida accettata,
  trust store di sistema verificato tramite bundle fixture, certificato
  non fidato rifiutato. Nessuna opzione TLS permissiva.
- Entrypoint production avviato sano sia con sia senza secret CA.
- Seconda release deliberatamente non avviabile: ripristinato image ID
  esatto precedente, health verde, marker runtime conservato.
- `php -l`: tutti i9 PHP modificati/nuovi, tramite container offline.
- `bash -n`: deploy e due runner nuovi; `sh -n` entrypoint; `git diff --check`
  verde. Nessun diff in `docker/local.sh`.
- Ultimi log privati: `/tmp/pos-sip036-unit.log` e
  `/tmp/pos-sip036-deploy.log`. Risorse Docker fixture rimosse dal cleanup.

### Limite prova offline

Il build originale non poteva scaricare Composer senza Internet, come
richiesto dal prompt. Nel solo Dockerfile della copia usa-e-getta il runner
sostituisce acquisizione dipendenze con vendor dell'immagine locale cached,
previo confronto esatto di ogni pacchetto/versione/reference source e dist
con composer.lock. Stadi applicativi e script deploy sono quelli consegnati.
Il Dockerfile reale conserva Composer install locked, senza percorsi alternativi.
Non e provato uno scaricamento Composer fresco o un build con cache vuota.

Non eseguiti: browser/Playwright, suite e2e con MySQL/Napay/Besu, pagamenti
reali BTC/TTS, login operatore contro Napay reale, prova gateway produzione,
VPS, rootless Docker, static analyzer non configurato per questo incarico.
Il test transport verso gateway condiviso non e stato lanciato: sandbox
esclusa dal perimetro. Nessuna dichiarazione end-to-end finanziaria.

## Integrazione riservata al master

1. Integrare i9 commit sul branch POS di integrazione; non usare `:dev` per
   produzione. Eseguire script dal checkout POS che sara rilasciato.
2. Riutilizzare rete production esterna privata gia preparata dal gateway;
   gateway raggiungibile dal POS all'host configurato nell'API URL, alias
   backend `pos-v2-web:80` per dominio pubblico POS. Nessuna porta POS host.
3. Napay deve accettare la subnet POS nella propria allowlist API. Secret
   client del POS deve corrispondere alla registrazione lato Napay.
4. Per HTTPS interno con CA privata gateway: impostare `NAPAY_CA_SOURCE` al
   certificato CA in file privato0600/directory0700. Per certificato pubblico
   attendibile non serve CA aggiuntiva. Verifica TLS sempre attiva.
5. Launcher orchestratore: chiamare `bash pos/v2/docker/deploy.sh <env> --check`
   in controllo e senza --check al rilascio. Non aggiungere un secondo servizio
   POS parallelo in compose orchestratore con stesso alias/progetto/runtime.
6. Eseguire prova integrata autorizzata: login, catalogo, apertura esclusiva,
   incasso e aggiornamento stato. Health verde non certifica questi flussi.

## Rischi e limiti operativi

- Rollback immagine soltanto: non ripristina env modificato, chiavi ruotate,
  database, gateway o contenuti sessione; configurazione deve restare compatibile.
- Runtime/parent progetto devono restare stabili fra release; backup separato.
- Richiesto Docker rootful senza user namespace remapping; uid33 inizializzato
  dall'entrypoint. Rootless richiede verifica ownership dedicata.
- Nessun rilascio VPS autorizzato da questo handoff.
