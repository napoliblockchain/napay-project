# C4 - Handoff agente Napay

## Workspace

- Worktree: `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`.
- Branch: `feature/v2-napay-backoffice-c4`, base `a3fd15f3` (C1 + test).
- Commit sul branch:
  - `5a39d763` fix(layout): testo leggibile nel popup "Aggiornamento Versione"
    (`views/layouts/snackbar.php`, una riga, richiesta diretta dell'utente;
    file di layout: da integrare a cura del master);
  - `7ca815cf`, `dff150e3`: cherry-pick autorizzati di `5c1fd920` e `00afe16a`
    (policy R1 e test), senza modifiche.
- Ambiente di test isolato nel worktree: vendor installato da `composer.lock`
  del worktree (composer 2.10.3, `--no-dev`, pacchetti e versioni identici al
  checkout principale, nessun symlink); cartelle ignorate `runtime/` e
  `web/assets/` create vuote come punti di mount.

## Stato (2026-11-12)

- [C4-BACKOFFICE.md](C4-BACKOFFICE.md) riscritto sulle regole definitive
  SIP-023: gate solo tramite `AccountEligibility`, scope del gestore da
  `merchantForManager`, concessioni solo su merchant qualificati e account
  operatore coerenti, riduzioni sempre possibili.
- Parti A-C (scope, terminali, profili esistenti, grant, D3): in implementazione.
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
- Sidebar: voce "Terminali POS" verso `pos-management/index` (patch alla
  consegna del codice A-C). Rotte: nessuna modifica a `config/web.php`.
- Integrazione di `5a39d763` (popup nuova versione).

## Test

- `tests/docker/account-eligibility.sh` nel worktree: 24 PASS, bootstrap
  `already-complete`.
- Test C4 A-C: in preparazione.

## Blocchi

- Inviti: review del contratto e decisione sull'unicità email.
