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
  - `0463cbc6` test(pos): suite C4 e runner dedicato.
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
- Integrazione di `5a39d763` (popup nuova versione).

## Test

- `tests/docker/account-eligibility.sh` nel worktree: 24 PASS, bootstrap
  `already-complete`.
- `tests/docker/pos-management.sh`: **49 PASS** + bootstrap `already-complete`.
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

- Inviti: review del contratto e decisione sull'unicità email.
