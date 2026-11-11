# SIP-021 - POS: login operatori, negozi autorizzati e apertura esclusiva

- Stato: OPEN (requisiti funzionali confermati; protocollo API da approvare).
- Area: POS / Autenticazione / Autorizzazioni / Integrazione Napay.
- Repo: `pos`, `napay`; orchestratore per documentazione e integrazione.
- Branch target: `feature/v2-yii2-php83-docker`.
- Segnalato: 2026-11-11.
- Dipendenze: TIP-004 (porting POS), TIP-009 (contratti API), TIP-020 (backend Napay).
- Regola di esecuzione: prima approvazione di questo SIP e dei dettagli della
  fase interessata, poi implementazione in piccoli commit verificati.

## Contesto

Il POS legacy usa un SIN nel login. La v2 dispone di una preview Yii2/PHP 8.3
avviata in Docker su `https://pos.localhost`, con tastierino e verifica importi:
non autentica operatori, non acquisisce POS e non esegue incassi.

La preview e gia stata realizzata nel perimetro TIP-004. Questo SIP formalizza
il lavoro successivo: non approva retroattivamente API o incassi inesistenti.
Napay resta il backend autorevole, sviluppato in parallelo da un altro agente.

## Proposta

Decisioni funzionali confermate dall'utente il 2026-11-11:

1. Un merchant puo avere piu negozi; ciascun negozio puo avere piu POS.
2. L'operatore accede con un account Napay base esplicitamente abilitato.
   Un utente puo essere assegnato a piu negozi; il solo ruolo base non concede
   accesso ai negozi o ai POS. Login con email, secondo il backend attuale.
3. Dopo login vede soltanto i POS autorizzati, presentati come
   `descrizione negozio - nome POS`. Nessun SIN o codice tecnico da conoscere.
4. Il SIN BTCPay resta un riferimento interno del backend, non una credenziale
   POS; il flusso TTS non dipende da un login BTCPay.
5. Un POS ammette una sola apertura/dispositivo attivo. Una seconda apertura,
   anche dello stesso utente, viene bloccata senza espellere quella attiva.
6. Sblocco forzato riservato ad admin oppure merchant proprietario del POS.
   L'operatore non puo sbloccare aperture altrui e un merchant non puo agire
   sui POS di un altro merchant.
7. Destinazione TTS: wallet unico del merchant, risolto dal backend. Nessun
   indirizzo wallet o merchant scelto liberamente dal client per ricevere fondi.
8. Primo collaudo finanziario futuro soltanto TTS su chain locale, senza
   denaro reale. Wallet distinti per negozio richiedono un SIP futuro separato.

### Fasi e gate

| Fase | Risultato | Gate prima del codice |
| --- | --- | --- |
| 0 | Contratto POS/Napay concordato | Approvare autenticazione, URL/JSON, assegnazioni, lock e revoca con agente backend. |
| 1 | Login e catalogo POS autorizzati, senza incassi | Contratto della fase 0 accettato; test account/grant e revoche definiti. |
| 2 | Apertura esclusiva, chiusura e sblocco manager | Protocollo concorrenza/fencing, ripresa e crash definito; test DB reali di test previsti. |
| 3 | Primo collaudo TTS locale | Prima completare il SIP con contratto richieste, QR/stato, idempotenza, rete/token e riconciliazione, oppure approvare un SIP collegato. |

Le fasi 1-3 non sono implementate. Un generico "vai" non sostituisce la
definizione e approvazione dei dettagli tecnici ancora aperti.

## Criteri di accettazione

- Utente con due negozi assegnati vede i POS di entrambi, non quelli di altri
  negozi; utente base senza grant non vede e non apre POS.
- Backend verifica scope e stato utente/POS a ogni operazione: conoscere un
  ID valido o manipolare il client non permette accessi trasversali.
- Catalogo filtrato prima di conteggi/paginazione; SIN, password, token e
  chiavi wallet non vengono mostrati o registrati nei log.
- Due acquisizioni concorrenti dello stesso POS: una sola riesce, l'altra
  riceve conflitto. Replay idempotente non crea un'altra apertura.
- Lock persistente lato backend: non basta un controllo JavaScript, una
  variabile di sessione locale o localStorage.
- Sblocco forzato autorizzato e tracciato; la vecchia apertura viene invalidata
  e non puo creare ulteriori richieste. Nessun takeover silenzioso.
- Rimozione grant, disabilitazione utente/POS e revoca sono effettive anche
  dopo login; heartbeat scaduto non autorizza uno sblocco automatico.
- Credenziali verificate da Napay senza copia degli hash nel POS. Cookie
  separati e sicuri, protezione CSRF browser, trasporto verificato, errori
  generici e nessun allentamento TLS/CORS per far funzionare l'integrazione.
- Dopo approvazione della fase 3, tutti i POS di uno stesso merchant usano
  il suo wallet; collaudo soltanto sulla chain locale e nessun pagamento reale.
- Ogni fase ha test pertinenti eseguiti, diff revisionato e piccolo commit.
  Mock o controlli strutturali non provano autenticazione o concorrenza reale.

## Impatto

- `pos/v2`: login operatore, selettore, gestione apertura e client backend.
- `napay`: account/assegnazioni, catalogo, lock e revoche, sblocco dal backoffice.
- Database/migrazioni Napay: da progettare con l'agente responsabile, nessuna
  modifica implicita da questo SIP e nessun accesso diretto del POS al DB.
- Gateway/reti/CA: verificare con il protocollo scelto, senza cambiare altre
  applicazioni o introdurre nuove porte in modo non concordato.
- Pagamenti BTC, storico/ricevute, PWA offline e wallet per negozio restano
  fuori da questa implementazione iniziale e richiedono documentazione prima del codice.

## Note implementative

- Autenticazione server-to-server con sessione opaca o login centralizzato:
  scelta ancora aperta, non dedotta dalla presenza di una bozza OpenAPI.
- Da confermare: formato identificativi, TTL e revoche, chiusura normale/logout,
  ripresa dopo refresh, gestione crash e prove di concorrenza.
- La proposta di rilascio normale da parte del titolare non equivale allo
  sblocco forzato riservato al manager; definire il protocollo prima della fase 2.
- Nessun nuovo codice monouso o pairing SIN: proposta superata dal login utente.
- Fonte normativa delle decisioni POS: questo SIP. Contratto funzionale e
  OpenAPI sono allegati di lavoro; in caso di divergenza aggiornare e approvare
  prima il SIP, poi gli allegati e solo dopo il codice.
- Il rispetto del gate e il nuovo processo richiesto dall'utente: non avviare
  l'implementazione di una fase finche il suo SIP/aggiornamento non e pronto.

## Allegati e stato attuale

- [TIP-004: migrazione e preview gia disponibile](TIP-004-pos-porting-yii1-yii2.md).
- [Contratto funzionale POS/Napay](../pos/v2/docs/NAPAY-CONTRACT.md).
- [OpenAPI proposta](../pos/v2/docs/pos-api.openapi.json):
  `draft-awaiting-backend-review`, nessun endpoint disponibile certificato.
- [Stato e limiti preview](../pos/v2/README.md).
- Il test `pos/v2/tests/api-contract.cjs` controlla struttura e riferimenti
  della proposta, non e un test di integrazione del backend.
