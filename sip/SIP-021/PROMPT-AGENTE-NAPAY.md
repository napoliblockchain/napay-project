# Prompt per agente Napay - incarico C4

Sei l'agente Napay backoffice; l'altra sessione e master per integrazione,
POS/API e assegnazione file. Obiettivo comune: collaudo Napay/POS entro
23 novembre 2026. Leggi prima `/var/www/documents/AGENTS_secure_development.md`,
`/var/www/blockchain-napoli/napay-project/sip/COORDINAMENTO.md`, SIP-021 e
`napay/tests/application/POS-CATALOG.md`. Standard documentale: sip/SIP, non tips/TIP.

## Workspace

Usa solo il worktree e branch assegnati dal master nell'handoff C1. Non lavorare
nel bind mount `/var/www/blockchain-napoli/napay-project/napay`. Non fare checkout
nell'altra sessione; non committare file gia modificati da altri. Non usare
sandbox, env, secret, runtime o DB condivisi per scritture/test. Nessun riavvio
stack, installazione globale o migrazione della sandbox. Nessun push automatico.

## Primo deliverable, da fare subito

Preparare `sip/SIP-021/C4-BACKOFFICE.md` nell'orchestratore, senza modificare
SIP-021 principale, e `C4-HANDOFF.md` con branch/base commit e file riservati.
Disegnare backoffice dedicato per terminali, profili operatore e grant:

- Un operatore appartiene a un solo merchant; puo avere grant per piu suoi
  negozi, mai negozi di altri merchant. Nessun grant implicito per ruolo.
- Tre AR C1 sono vincolanti: PosOperators, PosStoreOperators, PosTerminals.
  UUID generato server-side, default disabilitato, identita non riassegnabile,
  timestamp protetti e FK RESTRICT. Nessun delete o trasferimento automatico.
- Admin puo gestire le risorse autorizzate del backoffice; merchant solo risorse
  proprie, con controllo record-level anche sugli ID e sui POST manipolati.
- Definire prima chi crea/collega nuovi account operatore e come provare che un
  account sia assegnabile da quel merchant: non offrire una lista globale utenti
  al merchant e non consentire di rivendicare account altrui con un ID/email.
  Se manca una regola funzionale, segnalarla al master prima del codice.
- Scope prima di conteggi/paginazione e su ogni action; ActiveForm/CSRF,
  VerbFilter, encoding, errori generici, audit e transazioni sulle scritture.
- Mostrare disponibilita "Non verificata"; nessun comando di apertura o sblocco
  finche il master non consegna relativo contratto/servizio.

## Confine di scrittura proposto

Dopo approvazione dell'allegato C4 da parte del master, implementa su:
`controllers/PosManagementController.php`, `models/forms/pos/*`,
`components/pos/management/*`, `views/pos-management/*`,
`tests/application/pos-management.php`, eventuale runner test dedicato.
Riserva prima nomi/file nell'handoff e verifica che non esistano gia.

Non modificare API POS, repository POS, AR/migration C1, PosApi.php, Throttle.php,
Users/Stores/Merchants, controller condivisi, config/web.php, menu/layout,
runner runtime, composer o Docker. Per menu/rotte/shared integration consegna
la richiesta nell'handoff: la applica il master. Nessuna duplicazione del dominio
per aggirare questo confine; se serve cambiare un file condiviso, fermati su
quella modifica e concordala, proseguendo solo con attivita indipendenti.

## Test, commit e comunicazione

Usa DB Docker usa-e-getta e dati fixture. Testa admin, merchant proprietario,
merchant altrui, utente base, ID alterati, CSRF, metodi, grant cross-merchant,
abilitazioni/disabilitazioni, nomi malevoli e transazioni. Riusa pattern test
esistenti senza modificare fixture comuni in parallelo. Niente dati o segreti
nei log. Dichiara cosa non hai potuto verificare.

Piccoli commit solo dei tuoi file sul branch assegnato. Aggiorna C4-HANDOFF.md
con hash, test, file condivisi richiesti e blocchi. Non modificare il registro
master COORDINAMENTO.md. Il master integra dopo review; non presumere di poter
comunicare con l'altra chat senza un canale reale. Usa gli handoff come registro
persistente e invia all'utente una breve notifica del deliverable pronto.

Dopo C4, non iniziare pagamenti o provisioning BTCPay autonomamente: proponi
B0 di SIP-022, con istanza/versione, permessi e identita tecnica da approvare.
