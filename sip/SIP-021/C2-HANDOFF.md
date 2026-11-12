# C2/C3 - Handoff master, 2026-11-12

## Esito e commit

Catalogo autorizzato implementato, senza apertura di terminali o incassi.

- Napay `7ee57669`: GET /api/pos/v1/terminals, servizio catalogo e rotta.
- Napay `0275704f`: test HTTP/DB e runner dedicati, documentazione.
- POS `74e0287`: client TLS, vista catalogo, invalidazione sessione e test.
- POS `90fd41e`: README/contratto/OpenAPI e controllo strutturale.
- Approvazione C4 e D1-D3 utente pubblicate separatamente in `2c6eb55`.

## Verifiche eseguite

- 169 controlli catalogo HTTP/DB sullo stack MySQL usa-e-getta, piu controllo
  log Apache e bootstrap finale `already-complete`. Include admin/merchant con
  grant espliciti esclusi, cambio ruolo dopo login, budget JSON e cursor.
- Regressioni isolate: 51 C1, 62 login, 32 logout, bootstrap idempotente.
- POS: 37 catalogo client/vista/controller con trasporto simulato, 37 login,
  18 logout, 18 importi, 13 configurazione, 2 trasporto TLS reale, 7 percorsi.
- Browser reale: 24 login/catalogo/logout e 24 anteprima, mobile/desktop.
  La fixture sandbox admin ha lista realmente vuota: nessun seed operativo.
- JSON/OpenAPI, sintassi PHP/JS/shell e diff controllati. PHPStan/PHPCS non
  configurati. Revisione statica indipendente senza finding concreto C2/C3.

Test ripetibili: `napay/tests/docker/pos-terminals.sh` con dataset v2 revisionato,
`pos/v2/tests/catalog-client.php` e browser. Vedi POS-TERMINALS.md nel repo Napay.
I test simulati non provano scope backend; quelle prove sono nella suite HTTP/DB.

## Integrazione e limiti

Nessuna migration nuova, nessun riavvio Napay/gateway: solo rebuild POS.
Nessuna modifica a PosApi, Throttle, AR C1, fixture/runner comuni o file C4.
GET ricontrolla account base attivo, sessione, profilo/grant/terminale sullo stesso
merchant a ogni pagina. Cursor cifrato non concede accesso; stato solo unknown.
Niente disponibilita reale, lock, pagamenti, seed o cache grant.

Errore backend non mostra lista vecchia; invalid_token elimina custodia locale.
Il browser riceve solo cookie POS e dati pubblici, non bearer/key Napay.
Token in paginazione = cursor cifrato, non token di autenticazione.

## Per l'agente C4

Continuare nel worktree assegnato, base C1 invariata. Non fare cherry-pick di C2
nel branch integrazione e non modificare config/web.php o API: integra il master.
Le abilitazioni C4 devono scrivere i flag/grant C1 corretti; la sola esistenza
profilo/ruolo non rende visibile il terminale. Un titolare ha bisogno di account
base distinto per operare alla cassa, come deciso dall'utente.

Leggere C4-APPROVAZIONE.md: terminali/profili/grant/disable-revoca autorizzati;
contratto tecnico inviti da consegnare prima del codice inviti. Mantenere
handoff di codice e menu richiesto separati, senza edit ai documenti master.

Prossimo lavoro master: contratto apertura esclusiva/fencing e rilascio/revoca,
poi relativa implementazione. Questo catalogo non ne anticipa i permessi.
