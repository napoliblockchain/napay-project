# C1 - Handoff master, 2026-11-12

## Stato e commit

C1 chiuso, senza implementare C2/API catalogo o backoffice C4.

- Repo Napay, integrazione: `/var/www/blockchain-napoli/napay-project/napay`.
- Branch integrazione: `feature/v2-yii2-php83-docker`.
- `c357ec41`: migration 130000 e tre modelli C1.
- `a3fd15f3`: test C1, runner isolato e documentazione ripetibile.
- Revisione indipendente completata: corretti controllo database delle FK e
  test di riassegnazione grant; secondo passaggio senza ulteriori blocchi su quei fix.

## Evidenze

- Eseguiti 51 controlli C1 schema/modelli, 62 API login, 32 API logout su database
  Docker usa-e-getta; bootstrap ripetuto `already-complete`.
- Sintassi PHP/shell e diff controllati; PHPStan/PHPCS non configurati.
- Le tre tabelle della sandbox condivisa risultavano gia applicate da bootstrap
  precedente. Verificati in sola lettura definizioni e storico 130000 presente.
  Nessuna applicazione/riparazione/rollback o riavvio condiviso effettuato dal
  master durante la chiusura. Non serve rilanciare la migration sulla sandbox.
- Rimane modifica preesistente non committata in `napay/docker/LOCAL-BROWSER.md`:
  non e parte C1 e non e stata inclusa o scartata.

## Workspace assegnato all'agente Napay

- Worktree: `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`.
- Branch: `feature/v2-napay-backoffice-c4`.
- Base: `a3fd15f3`, include C1 e test. Worktree inizialmente pulito.
- Nessun env privato, vendor, runtime o stack copiato/montato dal workspace
  principale. Non puntare il nuovo lavoro alla sandbox DB condivisa.
- Primo incarico: seguire `PROMPT-AGENTE-NAPAY.md` nella stessa cartella.
  Produrre prima C4-BACKOFFICE.md e C4-HANDOFF.md; il master finalizza il
  contratto C2/API in parallelo. Non modificare i file master.

## Confine del contratto C1

Riutilizzare PosOperators, PosStoreOperators, PosTerminals. Un solo merchant
per operatore, grant espliciti solo ai suoi negozi, default disabilitati.
FK RESTRICT, identita non riassegnabili, timestamp protetti. Nessun grant
implicito per ruolo/proprietario. UUID generato server-side, non SIN.
Gestione ordinaria tramite abilitazione/disabilitazione; niente delete o
trasferimenti senza un futuro contratto esplicito e revoca delle sessioni.

Le API GET, policy assegnazione nuovi account dal merchant, UX manager, lock e
pagamenti non diventano approvati automaticamente per la presenza delle tabelle.
Scritture backoffice devono risolvere ownership lato server e usare controlli
record-level/CSRF/transazioni/audit. Riportare in C4 le decisioni mancanti.
