# C4 - Handoff agente Napay

## Workspace

- Worktree: `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`.
- Branch: `feature/v2-napay-backoffice-c4`, base `a3fd15f3` (C1 + test).
- Worktree pulito; nessun commit Napay finora.

## Stato (2026-11-12)

- Consegnato il contratto [C4-BACKOFFICE.md](C4-BACKOFFICE.md), in attesa di:
  - approvazione del master;
  - decisioni dell'utente D1 (chi collega gli account; proposta: solo admin),
    D2 (solo account base attivi), D3 (revoca sessioni POS alla
    disabilitazione del profilo).
- Nessun codice scritto. Nessun uso di sandbox, DB, env o stack condivisi.

## File riservati (verificati inesistenti su `a3fd15f3` e sul branch di integrazione)

- `controllers/PosManagementController.php`
- `models/forms/pos/*`
- `components/pos/management/*`
- `views/pos-management/*`
- `tests/application/pos-management.php`
- `tests/docker/pos-management.sh` (runner dedicato)

## Dipendenze in sola lettura (non modificate)

`models/PosOperators.php`, `PosStoreOperators.php`, `PosTerminals.php`,
`PosOperatorSessions.php`, `components/pos/PosApi.php` (solo `revoke`),
`components/User.php`, `components/Log.php`, `components/Crypt.php`,
`components/web/LinkPager.php`, `Users`/`Stores`/`Merchants`.

## Richieste per file condivisi (le applica il master)

- Sidebar: voce "Terminali POS" verso `pos-management/index` per admin e
  merchant. Patch fornita alla consegna del codice.
- Rotte: nessuna modifica a `config/web.php` necessaria (pretty URL senza
  strict parsing).
- Runner: dedicato; eventuale integrazione nel runner comune a scelta del master.

## Segnalazioni

- Registrazione pubblica: il ruolo merchant è scelto dall'utente
  (`SignupForm::is_merchant`). C4 non si fida del solo livello.
- `User::getMerchantId()` usa `merchants[0]`: ambiguo con più merchant per utente.

## Test

Nessuno ancora (solo documento). Piano nella sezione 6 del contratto.

## Blocchi

Codice fermo fino ad approvazione di C4-BACKOFFICE.md e decisioni D1-D3.
