# SIP-024 - WebSocket Node.js al posto del motore socket PHP

- Stato: OPEN - scelta Node.js confermata dall'utente; contratto e rollout da approvare.
- Area: Realtime / Notifiche / Docker / Sicurezza / Affidabilita.
- Repo: `napay-project`, `napay`, `pos`, `poawallet`.
- Branch proposto: `feature/v2-realtime-node`, worktree separato da assegnare.
- Segnalato: 2026-11-12.
- Dipendenze: SIP-002, SIP-008, SIP-009, SIP-014, SIP-016, SIP-021, SIP-023.
- Perimetro di questo commit: analisi e documentazione, nessuna implementazione,
  upgrade, modifica gateway, avvio container o rimozione di servizi esistenti.

## Contesto

L'utente richiede un server Node.js per ricevere messaggi realtime, seguendo
il modello gia usato in:
- `/var/www/theia/aigo/remote-assist-integration/ws-server`;
- `/var/www/txlab/ilnotturno/ws-server`.

PHP/Yii2 rimane backend applicativo: sessioni, identita, scope, grant, lock,
transazioni e stato autorevole. Non mantiene le connessioni WebSocket dei browser.
Il relay Node non firma transazioni, non custodisce chiavi wallet e non decide
che un pagamento sia avvenuto o che un POS possa aprirsi.

## Verifica repository e riferimenti locali

### Aigo e IlNotturno

Analizzati package.json, src/index.js, registry.js, handlers/subscribe.js,
utils/apiClient.js; inoltre logging e handler broadcast di IlNotturno.

Pattern riusabile: Node ESM, libreria `ws`, server HTTP con healthz,
registry delle connessioni, handler separati, ping/pong ogni 30 secondi e
API HTTP verso Yii2. E WebSocket standard, non Socket.IO: browser con client
WebSocket nativo, senza aggiungere un secondo protocollo.

**Non copiare senza adeguamento:**
- dump iniziale di process.env, che puo contenere segreti;
- whitelist Origin vuota che accetta qualsiasi origine;
- subscribe che assume user_id/is_admin dichiarati dal browser;
- broadcast a tutti i client per un messaggio ricevuto da un client;
- log del messaggio completo, eccezioni/request o risposte backend non filtrate.

Queste sono evidenze dei file letti, non una certificazione degli ambienti
in esercizio. Nessun sorgente Aigo/IlNotturno modificato e nessun env privato letto.

### Napay, POS e wallet attuali

- Non rilevato un demone socket PHP nel nuovo POS v2; inventariare processi
  effettivamente attivi prima di dichiarare dismesso il legacy.
- `poawallet/ws-notify` e gia Node.js con `ws`, ioredis e lock npm; il compose
  orchestratore contiene il servizio ws-notify e Redis. Non creare un nuovo
  relay PHP o un secondo stack Node equivalente ignorando questa base.
- L'implementazione wallet ha gia payload massimo 8192 e verifica l'identita
  tramite sessione Yii, non soltanto user_id dichiarato. Questi controlli e
  `ws-notify/tests/security.test.mjs` sono base di riuso/regressione.
- L'autenticazione attuale del wallet inoltra cookie al proprio backend:
  non e direttamente il contratto POS, il cui bearer Napay deve restare server-side.
- Il Dockerfile ws-notify usa Node 20; non replicarlo per il nuovo rilascio.
  Node 20 risulta EOL nella [tabella ufficiale delle release Node.js](https://nodejs.org/en/about/previous-releases).
  Scegliere LTS supportata e patch verificata al momento del lavoro, con lock
  e test di compatibilita; nessun upgrade eseguito da questo SIP.
- L'avvio wallet stampa REDIS_URL: se con credenziali, non deve essere loggato
  integralmente. Il compose pubblica una porta host: va rimossa dal default
  o limitata al loopback del solo profilo diagnostico durante il rollout.
- `poawallet/Dockerfile-wss` legacy avvia `/var/www/yii server/start 7502`
  su vecchia immagine PHP. E traccia di una precedente architettura, non prova
  che quel container sia oggi attivo.
- `WebsocketController::actionTrades()` richiama EthereumTransactions, che
  contiene un ciclo di scansione blockchain: non cancellarlo per somiglianza
  del nome. Trasporto socket e worker di dominio sono responsabilita diverse.

## Proposta

### Un unico motore Node, adattatori applicativi separati

Evolvere/riusare la base ws-notify esistente con backend/namespace espliciti
per wallet, Napay e POS. I riferimenti Aigo/IlNotturno sono modello operativo,
non codice da copiare integralmente. Evitare fork permanenti dello stesso relay.

In W0 riservare repository/ownership con l'agente wallet. Proposta packaging:
core condiviso sotto `napay-project/realtime/`, adapter/backend nei repo app;
non obbligare a spostare immediatamente il codice wallet durante il lavoro C4.
L'eventuale convivenza temporanea durante il passaggio deve avere un termine,
URL e publisher separati, senza doppia consegna o doppio motore autorevole.

Flusso logico:

```text
browser -- WSS /ws-notify --> Caddy --> Node ws-notify
                                      |           ^
                         ticket/auth  |           | eventi persistiti
                                      v           |
                              backend Yii2 --> outbox/publisher --> Redis

browser -- HTTPS API --> backend Yii2 --> DB / stato autorevole
```

L'API REST rimane necessaria per snapshot, recupero e comandi applicativi.
Un evento socket aggiorna la UI o richiede rilettura: non certifica il risultato
finanziario e non sostituisce l'autorizzazione al momento del comando.

### Autenticazione e sottoscrizioni

- Whitelist esatta di Origin/Host per ambiente, verificata all'upgrade; whitelist
  mancante = servizio non pronto, non allow-all. Origin e un controllo aggiuntivo,
  non una prova di identita. Proxy headers fidati solo dal Caddy assegnato.
- Contratto proposto: ticket breve monouso emesso dal backend proprietario della
  sessione via HTTPS e POST/CSRF; per POS il server POS usa il bearer Napay senza
  consegnarlo al browser. Non riusare direttamente quel bearer sul WebSocket.
- Ticket casuale con solo digest nello storage autorevole, durata proposta
  60 secondi, consumo atomico. Legato a sessione, origine/applicazione, tenant e
  scope autorizzato; nessuna fiducia in user_id, merchant_id o is_admin client.
- Browser invia il ticket nel primo frame auth, non nella query URL o localStorage.
  Prima dell'auth nessuna sottoscrizione/dato; timeout proposto 5 secondi.
  Errori/assenza backend rifiutano l'accesso, non abilitano modalita anonima.
- Node riscatta il ticket verso il backend configurato, con credenziale interna
  separata. Il browser non sceglie URL backend. HTTPS CA/hostname verificati,
  timeout 5 secondi, nessun redirect e limiti risposta. Non disabilitare TLS.
- Identita fissa per connessione; cambio account richiede chiusura e nuovo ticket.
  Registry pulito su close/error/nuovo scope: nessun legame residuo con l'utente precedente.
- Topic/risorse verificati dal backend secondo SIP-021/023. Socio PF/PG riceve
  solo eventi associativi propri; gestore solo proprio merchant; operatore solo
  scope dei propri negozi/POS, mai un broadcast globale per ruolo dichiarato.
- Il primo rollout non espone comandi browser che producono pagamenti, notifiche
  globali o sblocchi. Publisher di dominio autenticati su canale separato.

### Eventi e sicurezza delle notifiche

Envelope da finalizzare in W0: event_id, schema_version, type, occurred_at,
riferimento pubblico alla risorsa e revision; payload minimo strutturato.
Esempi proposti: notification.created, invoice.status_changed,
pos.opening_revoked, session.revoked. Non sono endpoint o tipi gia implementati.

- Eventi solo dopo commit dello stato autorevole, con outbox/retry quando
  richiesto dal dominio. Publisher isolati e autorizzati, niente publish libero
  dal browser. Nessun segreto, seed, bearer o dati associativi superflui nei messaggi.
- Namespace e credenziali Redis separano app/tenant; Redis non pubblicato all'host.
  ACL publisher/subscriber minime, segreti montati da file. Mai log di REDIS_URL
  completa, cookie, ticket, env o interi frame non affidabili.
- JSON validato e allowlist delle azioni; nessun HTML client da inoltrare o
  inserire con innerHTML. Compatibilita con payload HTML wallet legacy solo
  tramite adapter revisionato, non fiducia generica nel canale.
- Logout, disabilitazione, cambio ruolo/scopo e revoca grant/apertura fanno
  invalidare le sottoscrizioni. Autorizzazione riletta prima di consegnare eventi
  riservati; guasto auth/backend sospende invio e chiude, non usa vecchi grant.
- Una revoca Redis persa non deve lasciare capacita operative: i comandi restano
  API autorevoli, sempre con controllo attuale e fencing. Definire SLA di chiusura
  del socket e riconvalida in W0; non promettere revoca immediata dal solo Pub/Sub.

### Recovery e affidabilita

[Redis Pub/Sub](https://redis.io/docs/latest/develop/pubsub/) ha consegna at-most-once:
non e una coda durabile e una disconnessione puo perdere messaggi.

- DB e API sono fonte di verita. Reconnect con backoff/jitter, nuovo ticket e
  recupero snapshot; event_id/revision per dedup e gestione di eventi fuori ordine.
- Se servono replay/ack affidabili, usare outbox persistente e Redis Streams o
  meccanismo equivalente da approvare, non promettere exactly-once sul socket.
- Ping/pong, rilevamento connessioni morte, SIGTERM con chiusura ordinata e drain.
  Proposte iniziali: ping 30s, payload client 8 KiB, evento 16 KiB, buffer uscita
  256 KiB per connessione, limiti connessioni/topic/rate da fissare sul carico reale.
- Gestire backpressure e client lenti, niente accodamento illimitato. Errori async
  catturati senza dump request. Limiti e timeout non dipendono da dati client.
- Health liveness distinta da readiness: relay vivo non significa broker/auth
  pronti. Redis richiesto ma assente = readiness negativa, non falso funzionamento.
- Numero socket/tab non definisce l'apertura esclusiva del POS: quello e un lock
  backend, non una proprieta della connessione Node o del registry in memoria.

## Docker, Caddy e porte

- Container Node non-root, rootfs read-only, tmpfs necessari, limiti risorse,
  graceful stop, healthcheck e restart controllato. Lock npm e npm ci in build;
  nessuna copia di .env, chiavi o vendor app nell'immagine.
- HTTP upgrade/WSS dietro Caddy, TLS locale/prod gestito dal gateway esistente,
  nessuna gestione certificati manuale. [Caddy reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
  supporta WebSocket; verificare direttive disponibili nella versione installata.
- Endpoint proposto stesso host app `/ws-notify`, compatibile con il wallet;
  Node interno 14800, gia usato dal servizio esistente. Nessun nuovo listener
  pubblico: browser sulle porte gateway 80/443 o quelle gia configurate.
- 18110 e gia riservata in SIP-016: eventuale diagnostica opzionale solo
  127.0.0.1:18110, non pubblicazione predefinita che aggiri Caddy/TLS.
- Redis interno 6379 non e una porta host da aprire. Reti/app/broker/auth da
  censire prima del compose: il POS oggi usa una rete dedicata che va preservata,
  non collegato al web Napay in chiaro per far funzionare il realtime.
- CA pubblica interna montata dove necessaria per le chiamate backend; secret
  diversi per app/publisher. Policy CSP connect-src con soli endpoint WSS previsti,
  senza wildcard o riapertura di origini per aggirare un test browser.
- Nessun riavvio gateway condiviso in questa fase. Rollout/reload coordinato
  con master, wallet e C4; misurare reconnect dopo cambio configurazione Caddy.

## Micro-step e ownership

1. W0: inventario processi reali, producer/consumer PHP legacy, ticket/protocollo,
   canali, revoche, scope, compatibilita wallet e collocazione core comune.
2. W1: base Node esistente hardenizzata, LTS supportata, origin fail-closed,
   limiti/logging, health e test; niente copia di segreti o dipendenze obsolete.
3. W2: ticket backend/adattatori e publisher, con test multi-tenant reali;
   nessuna modifica non concordata a sessioni/API gia assegnate.
4. W3: compose/Caddy e client in ambiente isolato; test autorizzazione/recovery,
   poi rollout locale coordinato e confronto con notifiche/stato REST.
5. W4: disabilitare listener PHP solo dopo inventario e collaudo; rimuovere
   Dockerfile/entrypoint/client legacy inutili in commit separati e reversibili.
   Non eliminare worker chain o codice business solo perche chiamato websocket.

Master: contratto, coordinamento, gateway e integrazione. Agente realtime dedicato:
core Node e test in write set riservato. Agente wallet: adapter/sessione/UI wallet;
agente C4: backoffice, non il relay. Nessun edit a poawallet/ws-notify mentre
un altro agente lo possiede, senza handoff. Nuovo branch/worktree prima del codice.

## Criteri di accettazione

- Browser Napay/POS/wallet previsti ricevono eventi via WSS da Node, non da
  listener persistente PHP. PHP mantiene solo API/business/publisher.
- Origin errata, ticket scaduto/riusato, utente disabilitato, scope diverso o
  user_id/is_admin manipolati non concedono accesso. Due tenant non vedono eventi altrui.
- Logout/revoca e guasti auth sospendono flussi riservati; nessun lock o pagamento
  acquisito dal WebSocket. Stato REST dopo reconnect coincide con lo stato DB.
- Test client lento, ping/pong perso, JSON/frame grande, flood, riavvio Node,
  indisponibilita Redis/backend, eventi duplicati/fuori ordine e reconnect Caddy.
- Nessuna credenziale in log, URL, immagini o browser oltre ticket breve in memoria;
  nessuna porta relay/Redis pubblica nel default; CSP e CA verificate senza bypass.
- Test regressione wallet esistenti e browser reali aggiunti per ciascun adapter;
  test mock separati da prove reali. Zero incassi reali nel collaudo.
- Nessun worker business/chain perso nella rimozione dei file PHP legacy.

## Impatto e stato

File previsti dopo W0: core realtime, adapter backend/frontend, test, compose e
routing Caddy, variabili esempio senza segreti e documentazione operativa.
Questo SIP non li implementa. Prima del codice fissare ownership con agente wallet,
contratto dei ticket/eventi e versioni supportate; non allargare silenziosamente
il perimetro del collaudo al 23/11 per un nuovo sottosistema non verificato.

## Fonti tecniche

- [ws ufficiale: server, autenticazione e heartbeat](https://github.com/websockets/ws).
- [Caddy reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).
- [Redis Pub/Sub e limiti consegna](https://redis.io/docs/latest/develop/pubsub/).
- [Release supportate Node.js](https://nodejs.org/en/about/previous-releases).

Fonti consultate il 2026-11-12; nessun test runtime o benchmark eseguito per
questa analisi documentale. I sorgenti locali sono riferimenti, non approvazione
retroattiva dei loro controlli o delle versioni dipendenza.
