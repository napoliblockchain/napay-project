# SIP-035 - Incarico agente cod (2026-11-19)

Assegnato dal master. Leggi prima `sip/COORDINAMENTO.md`,
`sip/SIP-035-gestione-password-napay-wallet.md` e
`/var/www/documents/AGENTS_secure_development.md`. Rispondi in italiano.

## Dove lavori

| Repo | Worktree | Branch | Base |
| --- | --- | --- | --- |
| napay | `/var/www/blockchain-napoli/napay-worktrees/napay-password` | `feature/v2-password-change` | `593b2382` |
| poawallet | `/var/www/blockchain-napoli/napay-worktrees/poawallet-password` | `feature/v2-password-change` | `0272ccb` |

Mai nella cartella `napay-project/napay` o `napay-project/poawallet` (sono del
master e montate nella sandbox condivisa). Mai merge o cherry-pick sul branch di
integrazione, mai push: integra il master.

## Cosa fare

Implementare SIP-035 punti 1-5 (non il punto 6, due fattori):
1. Napay: "Cambia password" per l'utente collegato (password attuale, nuova,
   conferma), stesse regole della registrazione/reset (`SignupForm`,
   `ResetPasswordForm`), hash con l'algoritmo corrente.
2. Dopo il cambio: nuovo `authKey` (invalida "ricordami"), altre sessioni web
   chiuse, sessioni POS dell'utente revocate (riusa la revoca esistente delle
   sessioni operatore, senza cambiarne il contratto), email di avviso (senza
   password), riga nel registro attività.
3. Limite ai tentativi sulla password attuale (riusa `Throttle` così com'è),
   solo POST con CSRF, errori senza dettagli.
4. Admin: nessuna impostazione della password altrui; solo azione POST "invia
   link di reset" sulla scheda utente, stesso flusso di "password dimenticata".
5. poawallet: stessa funzione nel profilo, stesse regole; non tocca chiavi o
   seed del wallet.

Testi UI sempre `Yii::t` con sorgente inglese + traduzione nel catalogo it.
JS/CSS in asset bundle, mai inline. Niente modali del browser.

## File

Tuoi: file nuovi (form, view, mail, test, runner `tests/docker/*`), più le
azioni nuove in `napay/controllers/SiteController.php` o `UsersController.php`,
`napay/messages/it-IT/app.php` (solo righe aggiunte), voce di menu del profilo.
Nel wallet: `ProfilesController`/`UsersController`/`SiteController`, view,
mail e messaggi del wallet.

Dipendenze condivise da NON modificare (se servono cambi, scrivili nell'handoff):
`components/pos/PosApi.php`, `components/Throttle.php`, modelli
`Users`/`Stores`/`Merchants`, migration, `components/db/DatabaseRoles.php`,
layout principale, compose/launcher/stack. Nessuna migration: se serve una
colonna, proponila nell'handoff.

## Test

Solo stack usa-e-getta (`tests/docker/*.sh` sul tuo worktree), mai il DB o lo
stack della sandbox condivisa, nessun riavvio di `start-localhost.sh`.
`php -l` su ogni file PHP toccato (PHP solo in container). Copri: password
attuale errata, conferma diversa, regole minime, limite tentativi, CSRF, sessione
"ricordami" e sessione POS invalide dopo il cambio, email senza password, admin
che invia solo il link.

## Consegna

Commit piccoli con `git commit --only` dei tuoi file sul tuo branch. Alla fine
scrivi `napay-project/sip/SIP-035/HANDOFF-COD.md` (unico file tuo
nell'orchestratore, non committarlo: lo integra il master): commit, file, test
eseguiti e non eseguiti, rischi, eventuali modifiche richieste ai file condivisi.
