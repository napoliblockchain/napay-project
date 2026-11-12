# C2/C3 - Catalogo autorizzato POS: contratto di implementazione

- Data: 2026-11-12. Master: agente POS/API.
- Autorizzazione: utente ha richiesto di procedere dopo chiusura C1.
- Nessun lock, pairing, incasso o modifica a C1; C4 resta all'altro agente.

## API C2

Precisazione successiva [SIP-023](../SIP-023-profili-soci-merchant-operatori.md):
livello base e profilo/grant sono i filtri attuali, non la completa prova di
separazione socio/operatore. Questa ulteriore esclusione e da progettare e
implementare; il presente contratto non la dichiara gia disponibile.

`GET /api/pos/v1/terminals`, solo server-to-server, corpo vuoto.
Header: `X-POS-Client-Key` e `Authorization: Bearer napos_<43 base64url>`.
Riusa PosApi::authenticateClient/findActiveSession/throttle, senza modificarli.

Ordine: client autenticato, formato bearer, budget client, sessione attiva,
budget sessione, parametri e query catalogo. Chiave rimossa, scadenza, logout,
utente non attivo e password cambiata rendono il bearer inutilizzabile.

Parametri ammessi soltanto `limit` (stringa intera canonica 1..100, default 50)
e `cursor` (stringa base64url senza padding, non vuota, massimo 512 caratteri).
Array, campi ignoti, corpo GET non vuoto o cursor non valido: 400.

Risposta 200 esatta:

```json
{"items":[{"id":"UUID-v4","store_name":"Negozio","name":"Cassa","availability":"unknown"}],"next_cursor":null}
```

- Scope SQL prima di ordinamento e paginazione: account base attivo (decisione
  D2 utente, 2026-11-12), profilo dell'utente autenticato
  abilitato, grant abilitato, negozio e terminale dello stesso merchant, terminale
  abilitato. Nessun bypass per admin/merchant/base. No profilo/grant = lista vuota.
- Proiezione esatta dei campi sopra, nessun SIN, wallet, user ID o ID DB pubblico.
  `store_name` da stores.description; nomi UTF-8 non vuoti, massimo 256 caratteri.
  Dati incoerenti o schema mancante = 503, non catalogo vuoto inventato.
- Ordine stabile per ID interno terminale crescente (non campo pubblico);
  keyset dopo ultimo elemento emesso. Query massima limit+1 righe.
- Cursor cifrato/autenticato con Security Yii2, chiave derivata da bearer e
  client, contiene solo versione, posizione e limit. Non riutilizzabile tra
  sessioni/client o con limit diverso. Controlli sessione/grant rieseguiti anche
  sulle pagine successive, senza promettere snapshot stabile del catalogo.
- JSON massimo 16 KiB, compatibile col client POS. Anche prima del limite righe,
  terminare la pagina quando serve per rispettare il budget; next_cursor riparte
  dall'ultimo elemento incluso. Mai saltare righe o troncare il JSON.
- `availability` soltanto `unknown`: nessuna acquisizione o disponibilita reale.

| HTTP | Codice |
| --- | --- |
| 400 | validation_failed |
| 401 | unauthenticated (servizio), invalid_token (operatore) |
| 405 | risposta framework, altri metodi |
| 429 | rate_limited con Retry-After |
| 503 | backend_unavailable |

Budget separati dal login/logout: client 120/min e sessione 30/min. Chiavi cache
non contengono token in chiaro. Errori pubblici fissi e no-store, niente cookie,
CORS, token o query in log. Rete/TLS invariati. Nessun aggiornamento last_used_at
nel GET, nessun nuovo segreto o permesso di scrittura necessario per il catalogo.

## POS C3

Pagina account rilegge la API a ogni visita/paginazione. Token rimane nella
sessione PHP server; cursor cifrato puo comparire nel link di paginazione ma
non e credenziale ne contiene identificativi in chiaro. Nessuna cache grant.
Visualizzare `descrizione negozio - nome POS` e "Non verificata" senza pulsanti
di apertura. Stato vuoto esplicito, nomi codificati in HTML.

401 invalid_token: eliminare custodia locale e richiedere login; guasto/chiave
servizio errata/rate limit: errore generico con retry, niente lista precedente
spacciata per autorizzata. Cursor errato: 400 con link per ripartire dalla prima
pagina, senza riflettere input. Logout mantiene il contratto centrale esistente.
Nessun seed in sandbox per rendere artificialmente popolata la vista.

## File riservati e test

Master: nuovi TerminalCatalog/TerminalsController, regola in config/web.php,
repo POS e aggiornamento SIP/OpenAPI. Test delegabili soltanto a file nuovi
`tests/application/pos-terminals.php`, `tests/docker/pos-terminals.sh`.
Non modificare PosApi, Throttle, AR C1, fixture/runner comuni o file C4.

HTTP/DB isolati: due negozi assegnati e uno altrui; ruolo senza grant; profilo,
grant o terminale disabilitati; cursor manomesso/cross-session/cross-client,
revoca tra pagine, scadenza/password/stato account, parametri e metodi, JSON
entro 16 KiB anche con nomi lunghi, rate limit, assenza segreti e schema mancante.
Client/viste: parsing difensivo, errori, encoding, invalidazione sessione e retry.
Browser reale sandbox: login, lista vuota reale, paginazione quando disponibili
fixture isolate, nessun incasso. I mock non provano l'autorizzazione backend.
