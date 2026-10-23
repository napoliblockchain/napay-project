# TIP-014 - Piano unificazione: base Poawallet + moduli Tokenpay

- Stato: IN_PROGRESS
- Area: Wallet Delivery
- Repo: poawallet, tokenpay
- Branch target: feature/v2-yii2-php83-docker
- Segnalato: 2026-04-21

## Contesto
poawallet e migliore base funzionale wallet ETH/POA. tokenpay contiene moduli utili (admin/network/mailbox/logs/push) che possono accelerare evoluzione prodotto.

## Proposta
Strategia ibrida:
1. Tenere poawallet come trunk funzionale wallet.
2. Portare in poawallet moduli stabili da tokenpay in pacchetti incrementali.
3. Non copiare blocchi ciechi: ogni modulo deve passare smoke test e controllo dipendenze.

## Criteri di accettazione
- Wallet base (receive, send, transactions, wizard) resta operativo dopo ogni integrazione.
- Moduli importati da tokenpay sono raggiungibili via route e autorizzazioni corrette.
- Nessuna regressione su Erc20, nonce, gas, chainId e firma transazione.

## Impatto
- Repo poawallet (target principale).
- Repo tokenpay come sorgente moduli.

## Note implementative
Pacchetti di integrazione consigliati:
- Step 1.1: backlog tecnico e mapping moduli (COMPLETED).
- Step 1.2: pannello network/admin (blockchains, nodes, smartcontracts, standard values) (COMPLETED).
- Step 1.3: mailbox + push + websocket notifiche (IN_PROGRESS).
- Step 1.4: logs/profiles e rifiniture UI AdminLTE solo se servono al dominio wallet.
- Step 1.5: hardening PHP 8.3, upgrade dipendenze Yii2, dockerizzazione unificata. (COMPLETED, 2026-05-16)

### Log Step 1.5 (IN_PROGRESS, 2026-05-16)

Completato:

- Dockerfile: `php:7.2-apache` → `php:8.3-apache`, estensioni complete (intl, zip, sockets, opcache, gd, gmp, bcmath, pdo_mysql), composer installato nell'immagine, apache.conf creato
- `config/db.php`: env vars `DB_DSN/DB_USERNAME/DB_PASSWORD` con fallback a secrets.php (rimuove db-docker.php trick)
- `composer.json`: requisito PHP `>=5.6.0` → `>=8.1`
- `ws-notify/`: creato in `poawallet/ws-notify/` (Node.js, canale `poawallet:notify`), indipendente da tradarb
- `docker-compose.base.yml`: context ws-notify → `./poawallet/ws-notify`, env vars DB passate a wallet-web
- Rimossa dipendenza `consik/yii2-websocket` da composer.json
- Rimossi `daemons/NotificationsServer.php` e `commands/ServerController.php` (broken + legacy PHP ws)
- `commands/WebsocketController.php`: rimosso `actionIndex` PHP ws, mantenuto solo `actionTrades`

Chiuso:

- `swiftmailer` → `yiisoft/yii2-symfonymailer ^2.0`; config aggiornata in `web.php` e `test.php` con DSN symfony
- `sc0vu/web3.php`: constraint `php ^7.1` è solo metadata, il codice gira su 8.3; `composer install` richiede `--ignore-platform-reqs` (documentato nel Dockerfile) — accepted risk, rimpiazzo rimandato a refactor core wallet
- Image scan: `php:8.3-apache` ha CVE nel base Debian — accettabile in dev, in prod usare digest pinned o CI scan

### PHP 8.3 compat scan (COMPLETED, 2026-05-16)

Risultati:

- Zero funzioni rimosse in PHP 8.x nel codebase (each, create_function, strftime, ecc.)
- Zero `${var}` interpolation deprecata
- Zero errori PHP lint su tutto il codebase

### composer update (COMPLETED, 2026-05-16)

Aggiornamenti applicati:

- `yiisoft/yii2`: 2.0.43 → **2.0.55** (PHP 8.3 compat completa)
- `yiisoft/yii2-swiftmailer`: 2.1.2 → 2.1.3
- Vendor allineato

Problemi aperti rilevati:

| Pacchetto | Problema | Priorità |
| -- | -- | -- |
| `sc0vu/web3.php` | `dev-master` + `php ^7.1` — aggirato con `--ignore-platform-reqs` | Aperto |
| `brainfoolong/cryptojs-aes-php` | **RISOLTO** → `brainfoolong/js-aes-php` 1.0.5, namespace `Nullix\JsAesPhp\JsAesPhp` | DONE |
| `swiftmailer/swiftmailer` | Abandoned, rimpiazzo `symfony/mailer` rimandato | Aperto |
| `web-token/jwt-*` | Abandoned ma funzionali su PHP 8.3 (>=7.2) — rimandato con web-push | Aperto |

Rischi principali:
- conflitti tra naming model (ContractType vs ContractTypes), controller e route.
- differenze tema/view (views in poawallet vs themes/adminlte in tokenpay).
- dipendenze composer datate (php >=5.6, pacchetti dev-master).

## Backlog tecnico Step 1.1

- Moduli candidati import prioritario (tokenpay -> poawallet):
  - controllers/NodesController.php
  - controllers/BlockchainsController.php
  - controllers/SmartcontractsController.php
  - controllers/StandardBlockchainValuesController.php
  - controllers/StandardSmartcontractValuesController.php
  - models/Blockchains.php, models/Nodes.php, models/SmartContracts.php
  - models/StandardBlockchainValues.php, models/StandardSmartcontractValues.php
  - models/ContractTypes.php + mapping verso poawallet ContractType.php

- Dipendenze da armonizzare prima del merge:
  - naming classi query/search
  - permessi RBAC/access filters
  - mapping route in navigation layout

- Esclusioni iniziali:
  - moduli non wallet-core (profiles, parte logs) finche non serve per operativita.

## Log esecuzione Step 1.2

### Step 1.2a - Network/Admin base (COMPLETED, 2026-04-21)
Implementato su poawallet:
- nuovi controller top-level:
  - controllers/BlockchainsController.php
  - controllers/SmartcontractsController.php
  - controllers/NodesController.php
- nuovo search model:
  - models/search/NodesSearch.php
- aggiornamento navigation/settings:
  - views/layouts/_navbar.php
  - views/settings/index.php

Verifiche fatte:
- lint PHP su file nuovi/modificati: OK
- smoke route via bootstrap Yii:
  - blockchains/index OK
  - smartcontracts/index OK
  - nodes/update OK
  - route legacy settings/* ancora OK

Note:
- per ora controllo accesso su ruoli autenticati (@) per compatibilita con poawallet; hardening RBAC webmaster in Step 1.5.
- parte standard values chiusa nel successivo Step 1.2b.

### Step 1.2b - Standard values bridge (COMPLETED, 2026-04-21)
Implementato su poawallet:
- nuovi controller top-level:
  - controllers/StandardBlockchainValuesController.php
  - controllers/StandardSmartContractValuesController.php
- nuovi search model:
  - models/search/StandardBlockchainValuesSearch.php
  - models/search/StandardSmartContractValuesSearch.php
- hardening model standard token:
  - models/StandardSmartContractValues.php
  - aggiunto supporto `id_blockchain` + relation `blockchainStandard`
  - mapping `ContractType` (naming poawallet) in luogo di `ContractTypes` tokenpay
- nuove viste CRUD:
  - views/standard-blockchain-values/*
  - views/standard-smart-contract-values/*
- navigation/settings aggiornate:
  - views/settings/index.php
  - views/layouts/_navbar.php

Verifiche fatte:
- lint PHP su file nuovi/modificati: OK
- smoke route via bootstrap Yii:
  - standard-blockchain-values/index OK
  - standard-smart-contract-values/index OK

### Step 1.3 - Mailbox + push + websocket notifiche (COMPLETED, 2026-05-15)

Implementato su poawallet (baseline compatibilita tokenpay):

- nuovi controller:
  - controllers/PushController.php
  - controllers/MailboxController.php (bridge verso notifications center)
- nuovo daemon websocket:
  - daemons/NotificationsServer.php (PHP, consik/yii2-websocket - da sostituire in Step 1.5)
- nuovo comando console:
  - commands/WebsocketController.php
- update endpoint push UI:
  - views/users/manage-options_js.php (`push/save`)
- update navigation:
  - views/layouts/_navbar.php (link mailbox)
- frontend websocket integrazione (tokenpay-style adattata a poawallet):
  - views/layouts/main.php (global js options ws/push)
  - config/params.php (indirizzi WebSocket con fallback)
  - web/js/ws-websocket.js (socket subscribe/getNotifications/newMessage + fallback tx worker)
  - web/js/notifications-MainWorker.js (helper `notify.*` + fallback polling solo se ws assente)
  - controllers/BackendController.php (onclick mailbox compat `notify.openEnvelope(..., event)`)

Verifiche fatte:

- lint PHP su tutti i file nuovi: OK
- dipendenza consik/yii2-websocket presente in composer.json
- WebSocketServerAddress in params.php con fallback env
- navbar con link /mailbox/inbox presente
- notify.openEnvelope integrato in BackendController

Note:
- mailbox tokenpay completo non portabile 1:1 in poawallet per assenza modelli `Inbox/Outbox`; usato bridge su `MessagesController`/`NotificationsReaders`.
- daemon websocket PHP funzionale ma legacy; in Step 1.5 da sostituire con ws-notify Node.js (pattern identico a /var/www/tradarb/ws-notify: `ws` lib + Redis pub/sub + fetch backend).
- protocollo ws client-side gia compatibile (subscribe/getNotifications/newMessage/checkTrades) - nessuna modifica JS necessaria al cambio daemon.

### Nota commit (da fare prima di Step 1.4)

File untracked pronti per il commit in poawallet (Step 1.2 + 1.3):

- controllers/BlockchainsController.php, NodesController.php, SmartcontractsController.php
- controllers/StandardBlockchainValuesController.php, StandardSmartContractValuesController.php
- controllers/MailboxController.php, PushController.php
- commands/WebsocketController.php
- daemons/NotificationsServer.php
- models/search/NodesSearch.php, StandardBlockchainValuesSearch.php, StandardSmartContractValuesSearch.php
- views/standard-blockchain-values/*, views/standard-smart-contract-values/*

.gitignore poawallet gia esclude `/vendor` correttamente.
yii-1.1.22/vendor: questo repo (napay-project) ha .gitignore solo con `.env`; se si intende committare
la cartella orchestratore, aggiungere `yii-1.1.22/vendor/` al .gitignore di napay-project.
Da valutare anche: `*/vendor/`, `*/node_modules/`, `*/.env` come regole globali nel napay-project .gitignore.

### Step 1.4a - Rifiniture UI (COMPLETED, 2026-05-16)

Obiettivo: allineamento tema, navbar attiva, breadcrumb, responsive check. Nessuna modifica DB.

Implementato su poawallet:

- navbar active state: `$active()` helper con prefix matching su `Yii::$app->requestedRoute`; tutti gli `<li>` ricevono `class="active"` sulla sezione corrente
- fix titolo `send/index.php` e `receive/index.php`: `Yii::$app->id` → `Yii::t('app', ...)`
- breadcrumb non implementato: UI mobile usa back button in `_header.php`, pattern corretto

Verifiche fatte:

- lint PHP su file modificati: OK

Note:

- `languageSwitcher` non presente in poawallet, non necessario.
- `user::isWebmaster()` dipende da `Profiles` + `privilege_id` su Users - rimandato a Step 1.4b.
- breadcrumb assente by design: la UI e mobile-first con back button in header.

### Step 1.4b - Logs + Profiles + RBAC base (COMPLETED, 2026-05-16)

Implementato su poawallet:

- migrations: `profiles`, `privilege_id` su `mp_users`, `logs` (da eseguire manualmente)
- `models/Profiles.php` + `ProfilesQuery` + `ProfilesSearch`
- `models/Logs.php` + `LogsQuery` + `LogsSearch` + metodo statico `Logs::write()`
- `components/UserRole.php` (PascalCase, sostituisce `user` tokenpay): `isWebmaster`, `isUser`, `can`, `privilegeLevel`, `privilegeName`
- `controllers/ProfilesController.php` (CRUD, solo webmaster)
- `controllers/LogsController.php` (index+view+delete, solo webmaster)
- views: `profiles/` (index, view, create, update, _form) + `logs/` (index, view)
- `models/Users.php`: aggiunto `privilege_id`, relation `getProfile()`
- `controllers/SiteController.php`: `Logs::write()` al login
- `views/layouts/_navbar.php`: voci Profiles e Logs visibili solo a webmaster

Verifiche fatte:

- lint PHP su tutti i file: OK

Note:

- componente rinominato `UserRole` (non `user` come in tokenpay) per rispettare naming PHP
- migrations NON eseguite automaticamente — eseguire manualmente: `php yii migrate`
- log writer aggiunto solo al login; altri eventi (send tx, logout) da aggiungere progressivamente

### Step 1.4b - Logs + Profiles + RBAC base (OPEN)

Obiettivo: portare Logs e Profiles da tokenpay + sistema ruoli minimo.

Richiede:

- Nuova tabella `profiles` (migration)
- Colonna `privilege_id` su `mp_users` (migration)
- Porting `app\components\user` (isWebmaster, can, privilegeLevel)
- Porting `Profiles` model + query + search + controller + views
- Porting `Logs` model + query + search + controller + views (con writer negli eventi chiave)
- Rimandato a Step 1.5 per coerenza con hardening RBAC pianificato

Criteri accettazione:

- Wallet core non regredisce
- Nessun modello non-wallet importato senza necessita

## Verifica repository
- /var/www/napay-project/poawallet/controllers/WalletController.php
- /var/www/napay-project/poawallet/controllers/SendController.php
- /var/www/napay-project/poawallet/controllers/NodesController.php
- /var/www/napay-project/poawallet/controllers/SmartcontractsController.php
- /var/www/napay-project/poawallet/controllers/BlockchainsController.php
- /var/www/napay-project/poawallet/controllers/StandardBlockchainValuesController.php
- /var/www/napay-project/poawallet/controllers/StandardSmartContractValuesController.php
- /var/www/napay-project/poawallet/models/search/StandardBlockchainValuesSearch.php
- /var/www/napay-project/poawallet/models/search/StandardSmartContractValuesSearch.php
- /var/www/napay-project/poawallet/views/standard-blockchain-values/index.php
- /var/www/napay-project/poawallet/views/standard-smart-contract-values/index.php
- /var/www/napay-project/tokenpay/controllers/NodesController.php
- /var/www/napay-project/tokenpay/controllers/SmartcontractsController.php
- /var/www/napay-project/tokenpay/controllers/StandardBlockchainValuesController.php
- /var/www/napay-project/tokenpay/controllers/StandardSmartcontractValuesController.php
- /var/www/napay-project/tokenpay/daemons/NotificationsServer.php

### Correzione sicurezza Step 1.3 (2026-10-23)

Implementazione corrente: `poawallet/ws-notify` Node.js. Il daemon PHP legacy
resta rimosso, come previsto dalla migrazione Step 1.5.

- `subscribe` verifica il cookie della sessione tramite `backend/notify`; l'identita
  viene restituita da Yii. Un eventuale ID dichiarato diverso viene rifiutato.
- Ogni richiesta notifiche riverifica la sessione. Sessione scaduta, backend
  indisponibile o risposta inattesa negano accesso e chiudono il socket.
- Rimosso accesso a `backend/notify` mediante secret interno e `user_id` arbitrario.
  Redis resta il canale interno per invalidare/aggiornare le notifiche.
- Backend restituisce il payload legacy, adattato dal servizio Node al protocollo
  `endnotifications_response`/`html` atteso dal frontend.
- Ricezione non chiama piu `push/notified`: lo stato letto cambia su click o
  esplicito "Mark all as read", mediante POST con CSRF e filtro esatto proprietario.
- Descrizioni notifiche codificate HTML. Endpoint push protetti da autenticazione,
  POST e CSRF.
- Gateway espone `/ws-notify` sul dominio wallet; fallback applicativo e `.env.example`
  usano il percorso relativo. Impostare `WEBSOCKET_URL=/ws-notify` e
  `WEBSOCKET_URL_LOCALHOST=/ws-notify` anche negli ambienti esistenti e abilitare il
  profilo Compose `realtime`. I cookie di sessione devono essere disponibili al
  percorso websocket. Configurare `NOTIFY_ALLOWED_ORIGINS` con l'origine browser
  completa, inclusa eventuale porta HTTPS non standard.

Verifica ripetibile:

```sh
cd poawallet/ws-notify
node --test --test-timeout=15000 tests/security.test.mjs
cd ..
php tests/security/notifications.php
```

Eseguiti: 4 test Node (backend HTTP simulato, websocket reale, frontend VM) e
20 controlli Yii su SQLite in memoria con PHP 8.3 in Docker, senza DB operativo.
I test non caricano credenziali applicative. Nessuna verifica browser/manuale
push o invio ETH/POA effettuata in questo intervento.

### Pin PHP 8.3.36 (2026-10-23)

- `Dockerfile`: `php:8.3-apache` → `php:8.3.36-apache` (patch release con fix di sicurezza, base Debian 13.7).
- `composer.json`: requisito PHP `>=8.1` → `>=8.3`; `composer.lock` aggiornato solo nel content-hash, nessuna versione cambiata.
- Verifiche su `php:8.3.36-cli`: lint 248 file OK, build layer di sistema ed estensioni OK, `tests/security/notifications.php` 20/20 PASS.
- `composer audit`: 26 advisory su 9 pacchetti. Aggiornati solo i pacchetti vulnerabili:
  guzzle 7.10.0 → 7.16.0, promises 2.3.0 → 2.6.0, psr7 2.9.0 → 2.13.2, symfony/mailer 6.4.34 → 6.4.46,
  symfony/mime 7.4.9 → 7.4.19, polyfill-intl-idn 1.37.0 → 1.43.0, phpseclib 2.0.54 → 2.0.55,
  yii2-gii 2.1.4 → 2.2.7 (`require-dev` `~2.2.5`). Residui: 6 advisory su 3 pacchetti.
  - `phpseclib` (medium, X25519): fix solo in 3.0.57+, bloccato da `sc0vu/web3.php` e `web3p/ethereum-util` (`~2.0`). Si chiude col rimpiazzo di sc0vu.
  - `symfony/dom-crawler`, `symfony/yaml` (low): solo dev, trascinati da codeception 4 e `symfony/browser-kit <=4.2.4`.
- Verificato dopo update: test sicurezza 20/20 PASS, smoke mailer/mime/guzzle/phpseclib OK. Non verificati: invio email reale, flusso send ETH/POA.
- `Dockerfile-wss` (PHP 7.2) resta nel repo ma e morto: avvia `server/start`, comando rimosso in Step 1.5. Da eliminare.

### Segreti fuori dall'immagine (2026-10-23)

- `config/secrets.php` e `config/encrypt.json` non sono piu letti. Tutta la configurazione arriva da variabili d'ambiente (`.env` passato con `env_file`), lette da `config/env.php`: variabile obbligatoria mancante → avvio bloccato, messaggio con il solo nome.
- `config/db.php`, `params.php`, `web.php`: valori da env. OAuth GitHub/Telegram non piu mappati per `SERVER_NAME`: un valore per ambiente.
- `WebApp::encrypt/decrypt`: chiave/IV da `ENCRYPT_*`, stessi valori di `encrypt.json` (i dati gia cifrati restano leggibili).
- `Erc20` faucet zerogas: se `SEALER_ACCOUNT_3`/`SEALER_PRVKEY_3` non sono configurati non invia gas invece di andare in errore.
- `.dockerignore`: esclusi `.env*`, `secrets.php`, `encrypt.json`, `.git`, test, runtime/logs. `.env.example` con tutte le variabili.
- `.env` locale generato dai valori esistenti (permessi 600, in `.gitignore` e `.dockerignore`).
- Verifiche: 29/29 valori config identici ai legacy; cifratura identica all'algoritmo precedente; immagine buildata senza file segreti (0 file con valori segreti); env letto da mod_php sotto Apache; senza env avvio bloccato; test sicurezza 20/20 PASS.
- Aperti:
  - compose orchestratore: `wallet-web` deve ricevere `env_file: ./poawallet/.env`.
  - `web/index.php` forza `YII_ENV=dev` e `YII_DEBUG=true`: con `vendor` `--no-dev` l'app non parte (`yii\debug\Module` assente); in produzione esporrebbe debug/gii.
  - immagine con `display_errors` attivo (nessun `php.ini-production`).
  - `secrets.php`/`encrypt.json` restano sul disco locale: eliminarli dopo aver verificato `.env`; i valori per i domini di produzione (GitHub/Telegram) sono ancora solo li.
  - chiavi sealer usate dal faucet: sostituire con un account dedicato a fondi limitati e ruotare le chiavi sealer esposte nelle immagini precedenti.

### Immagine autosufficiente dev/prod + fix PHP 8 (2026-10-23)

- PHP 8.3.36 riverificato su php.net: ultima release di sicurezza del ramo 8.3 (2026-10-21).
- `Dockerfile` multi-stage: composer `2.10.3` nella build (nessun PHP o `vendor` richiesto sull'host); target `prod` (default) e `dev`.
  - prod: `php.ini-production`, `YII_ENV=prod`, debug/gii/`requirements.php` assenti, composer assente, codice di proprieta root; scrivibili solo `runtime`, `html/assets`, `logs`.
  - dev: dipendenze dev, `php.ini-development`, debug/gii.
- `web/index.php`, `yii`: `YII_ENV`/`YII_DEBUG` da env, default `prod`; in prod debug sempre spento.
- `.dockerignore`: escluso `web/info.php` (`phpinfo()` pubblico: con i segreti in env li avrebbe esposti tutti), `web/index-test.php`, `vendor` locale.
- Fix PHP 8 (errori fatali "Non-static method ... cannot be called statically", sfuggiti allo scan del 2026-05-16): `Logo::footer` (login in 500), `Messages::push/saveReader/log/appTitle` (invio tx e notifiche), `WebApp::si_formatter/si_classifier`.
- Verifiche con MySQL 8.4 temporaneo + migration: login, home, reset password 200; wallet/send redirect al login; prod: gii/debug 404, `display_errors` off, senza env risposta 500 vuota; dev: gii/debug 200. Lint completo OK, test sicurezza 20/20 PASS.
- Aperti: `web/info.php` va eliminato dal repo; `Logo::header` usa API Yii1 (`Yii::app()`), non chiamato; `Messages::log` scriverebbe la chiave VAPID se riattivato; flussi autenticati (send ETH/POA, push) non provati.

### Rotazione chiavi esposte (2026-10-23)

Check gitleaks (storia completa, tutti i repo; tutti pubblici tranne tokenpay):
- `COOKIE_VALIDATION_KEY` in uso = valore committato nel 2021 in `config/web.php` → ruotata (nuovo valore solo in `.env`).
- Chiave privata VAPID in chiaro nella migration `m210415_085447_create_vapid_table` → coppia nuova in `.env` (`VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY`), letta da `Settings::vapid()`; push disattivate se assenti. Migration ripulita; `m261023_100000_clear_vapid_keys` svuota la tabella `vapid`.
- Effetti: utenti da riloggare (cookie); iscrizioni push da rinnovare (chiave pubblica cambiata). In produzione impostare gli stessi tre valori nuovi nel suo `.env`.
- Verifiche: migration applicata su MySQL 8.4 temporaneo; login/home 200 su dev e prod; test sicurezza 20/20 PASS; gitleaks sul codice attuale: solo falso positivo `lightwallet.min.js`.
- Fuori poawallet: chiavi Besu in `docs/Besu/*.md` (repo pubblico `napay-docs`, non coincidono con i sealer in uso: da rimuovere e considerare bruciate); stash locale napay `eaa529dd` con `secrets.php`.
