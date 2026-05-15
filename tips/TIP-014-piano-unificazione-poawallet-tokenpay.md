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
- Step 1.5: hardening PHP 8.3, upgrade dipendenze Yii2, dockerizzazione unificata.

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

### Step 1.4 - Logs/profiles e rifiniture UI (OPEN)

Obiettivo: portare in poawallet i moduli logs e profiles da tokenpay, solo le parti utili al dominio wallet.

Candidati da valutare:

- Logs: storico operazioni per admin (da tokenpay controllers/LogsController.php se esiste)
- Profiles: estensione dati utente wallet (avatar, preferenze display)
- Rifiniture AdminLTE: allineamento tema, breadcrumb, menu attivo, responsive check

Criteri accettazione:

- Wallet core (send/receive/transactions/wizard) non regredisce
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
