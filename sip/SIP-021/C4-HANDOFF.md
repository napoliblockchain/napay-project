# C4 - Handoff agente Napay

## Workspace

- Worktree: `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`.
- Branch: `feature/v2-napay-backoffice-c4`, base `a3fd15f3` (C1 + test).
- Commit sul branch:
  - `5a39d763` fix(layout): testo leggibile nel popup "Aggiornamento Versione"
    (`views/layouts/snackbar.php`, una riga, richiesta diretta dell'utente;
    file di layout: da integrare a cura del master);
  - `7ca815cf`, `dff150e3`: cherry-pick autorizzati di `5c1fd920` e `00afe16a`
    (policy R1 e test), senza modifiche;
  - `1c88626d` feat(pos): backoffice C4 parti A-C (scope, terminali, profili
    esistenti, grant, revoca D3);
  - `0463cbc6` test(pos): suite C4 e runner dedicato;
  - `842ea694` fix(pos): C4-RV1/RV2, letture correnti e revoca sotto lock;
  - `704a9323` test(pos): gare a due connessioni per RV1 e RV2.
- Ambiente di test isolato nel worktree: vendor installato da `composer.lock`
  del worktree (composer 2.10.3, `--no-dev`, pacchetti e versioni identici al
  checkout principale, nessun symlink); cartelle ignorate `runtime/` e
  `web/assets/` create vuote come punti di mount.

## Stato (2026-11-12)

- [C4-BACKOFFICE.md](C4-BACKOFFICE.md) riscritto sulle regole definitive
  SIP-023: gate solo tramite `AccountEligibility`, scope del gestore da
  `merchantForManager`, concessioni solo su merchant qualificati e account
  operatore coerenti, riduzioni sempre possibili.
- Parti A-C (scope, terminali, profili esistenti, grant, D3): implementate e
  testate, pronte per review. File: `controllers/PosManagementController.php`,
  `components/pos/management/{Scope,PosManagement,ManagementException}.php`,
  `models/forms/pos/{TerminalForm,GrantForm}.php`, `views/pos-management/*`.
  - Gate solo via `AccountEligibility`; scope ricalcolato dentro la
    transazione dopo il lock del merchant; record riletti `FOR UPDATE`.
  - Concessione rifiutata dai gate: flash generico + evento di sicurezza.
  - Parametri delle azioni tipizzati `string`: array nella query = 400.
- Parte D (inviti): contratto proposto nella sezione 5, in attesa di review.
  Nessuna migration né codice inviti.
- Nessun uso di sandbox, DB, env o stack condivisi.

## Correzioni review master (C4-REVIEW-MASTER.md)

- **C4-RV1** (`842ea694`): ogni scrittura C4 apre la transazione in
  `READ COMMITTED` (solo quella transazione, nessuna configurazione globale).
  Dopo il lock `FOR UPDATE` del merchant, scope (`merchantForManager`) e gate
  R1 leggono lo stato committato, non lo snapshot aperto dalle letture-indizio.
  La policy R1 non è stata copiata né modificata.
- **C4-RV2, lato C4** (`842ea694`): `operator-disable` blocca merchant e
  profilo, poi legge con `FOR UPDATE` tutte le sessioni non revocate e le
  revoca (`PosApi::revoke`, invariato); il lock del profilo resta fino al
  commit. Le sessioni scadute ma non revocate vengono revocate anch'esse.
- **Ordine dei lock C4**: merchant -> profilo operatore -> negozio ->
  grant/terminale -> sessioni. Compatibile con il protocollo del master
  (merchant, profilo, sessioni). Il login (master) deve controllare profilo
  attivo e R1 sotto lock del profilo prima di inserire la sessione: con il
  disable che tiene quel lock fino al commit, il login attende e poi trova il
  profilo disabilitato.
- **Test a due connessioni** (`704a9323`): la connessione B blocca la riga
  merchant; la scrittura C4 (processo separato) apre la transazione, legge
  l'indizio e attende il lock; B committa il cambio e rilascia. Casi:
  - cambio titolare del merchant -> vecchio gestore negato (404);
  - account operatore disattivato -> abilitazione profilo rifiutata;
  - nuova sessione committata dopo lo snapshot -> revocata dal disable;
  - riabilitazione -> nessuna sessione torna attiva.
  Prova sul codice precedente (`0463cbc6`): falliscono tutti e tre i casi
  RV1/RV2. Con la correzione: **53 PASS**, bootstrap no-op.
- Non coperto qui (master): login API contro disable concorrente, profilo già
  disabilitato al login. D3 non dichiarato chiuso finché il lato API non è
  integrato e testato.

## File riservati

- `controllers/PosManagementController.php`, `views/pos-management/*`
- `models/forms/pos/*`, `components/pos/management/*`
- `tests/application/pos-management.php`, `tests/docker/pos-management.sh`
- Parte D, solo dopo review:
  `migrations/m261112_140000_create_pos_operator_invitations.php`,
  `models/PosOperatorInvitations.php`, `controllers/PosInvitationController.php`,
  `views/pos-invitation/*`, `mail/posOperatorInvitation*.php`

## Dipendenze in sola lettura (non modificate)

`components/identity/AccountEligibility.php`, AR C1, `PosOperatorSessions`,
`components/pos/PosApi.php` (solo `revoke`), `components/Throttle.php`,
`components/User.php`, `components/Log.php`, `components/Crypt.php`,
`components/web/LinkPager.php`, `Users`/`Stores`/`Merchants`.

## Richieste al master

- Unicità o serializzazione dell'email normalizzata su `users` (contratto
  sezione 5, "Concorrenza ed email"): blocca il codice inviti.
- Review della parte D e via libera alla migration `m261112_140000`.
- Sidebar (`views/layouts/sidebar.php`, riga 12): la voce esistente "Pos"
  punta a `pos/index`, controller che non esiste più. Patch proposta:
  `['label' => Yii::t('app', 'Terminali POS'), 'url' => ['pos-management/index'], 'iconStyle' => 'fas', 'icon' => 'mobile-alt', 'visible' => \app\components\pos\management\Scope::current() !== null]`.
  Rotte: nessuna modifica a `config/web.php`.

## Test

- `tests/docker/account-eligibility.sh` nel worktree: 24 PASS, bootstrap
  `already-complete`.
- `tests/docker/pos-management.sh`: **53 PASS** (49 + 4 gare RV1/RV2) +
  bootstrap `already-complete`.
  Ruoli (admin, gestore, gestore altrui, merchant non qualificato, base,
  operatore, anonimo), scope di elenchi e selettori, UUID/ID altrui o
  malformati, POST con campi extra, CSRF assente 400, GET su scritture 405,
  nome malevolo codificato, gate su socio/operatore incoerente/account
  inattivo/merchant non qualificato, riduzioni consentite, D3 (2 sessioni
  revocate, altre intatte, riabilitazione senza riattivazione), scope del
  gestore ricalcolato sotto lock, due grant identici da due processi = 1 riga,
  audit `data` senza email o credenziali, nessun socio/profilo implicito.
- Regressioni nel worktree, tutte verdi:
  - `account-eligibility.sh`: 24 PASS;
  - `pos-catalog.sh`: 51 C1, 62 login API, 32 logout API;
  - `runtime.sh` completa (include il popup `5a39d763`): 668 righe PASS, tra
    cui 37 service worker, 68 reset password, 92 attivazione, associazione
    40 + 56, quote 40, PayPal webhook 34, BTCPay 34, registro 20, POS 62 + 32;
    riavvio e bootstrap no-op.
- Non verificato: resa grafica nel browser (nessun browser automatico).

## Blocchi

- Inviti: codice e DDL bloccati fino all'indice UNIQUE sull'email normalizzata
  (master). Timestamp `m261112_140000` resta riservato.
