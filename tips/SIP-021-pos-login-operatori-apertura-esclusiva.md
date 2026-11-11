# SIP-021 - POS: login operatori, negozi autorizzati e apertura esclusiva

- Stato: IN_PROGRESS (login/logout backend e client POS implementati il 2026-11-11; catalogo e aperture da definire).
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

### Flusso login approvato (2026-11-11)

L'utente ha scelto **login nel POS, verifica API Napay**, non reindirizzamento
al login del backoffice. Il browser invia email/password al proprio server POS
con HTTPS e CSRF; il POS le inoltra a Napay tramite canale server-to-server
verificato. Napay verifica credenziali e stato account con la logica centrale.

La password non viene persistita o registrata. Il token restituito da Napay
resta soltanto nella sessione server POS; il browser conserva un cookie POS
HttpOnly/Secure, separato da quello Napay. Rigenerare la sessione al login.
Niente copia utenti/hash, token in URL/localStorage o login via SIN.

Questa scelta chiude il dubbio login POS contro redirect/SSO. Restano da
concordare col backend: autenticazione del servizio, endpoint/JSON effettivi,
durata e revoca del token, trust CA e routing interno. Il SIP non considera
questi dettagli automaticamente approvati insieme alla scelta del flusso.

### Contratto `POST /api/pos/v1/sessions` (backend, APPROVATO dall'utente il 2026-11-11)

Scelte confermate dall'utente:
- autenticazione del servizio con chiave, rete dedicata e TLS (mTLS rinviato);
- sessione di 12 ore assolute;
- risposta con il solo `display_name`;
- rete separata per il POS.

Proposta dell'agente Napay dopo l'ispezione del backend. Le differenze rispetto
alla bozza OpenAPI sono marcate con **Δ**. Il codice parte solo dopo la conferma.

#### Rilevazioni sul backend (commit napay `a27bfe5a`)

- Login centrale: `LoginForm`/`Users::findByEmail` (email univoca, ambigua =
  nessun utente) e `validateStatus` (`is_active = 1`). Va riusato.
- Il login web non ha rate limit (lacuna preesistente, fuori da questo step).
  Il pattern di throttling esistente è cache + mutex (`EmailRequestForm`).
- Non esistono API POS. `users.accessToken` è in chiaro e non si usa per il POS.
- L'esempio `ilnotturno/controllers/api/v1` non si usa come modello: confronto
  del segreto non a tempo costante, 200 su accesso negato, CSRF disattivato in
  un controller con sessione, nessun rate limit.
- **Rete:** il container POS `pos-v2-local-web-1` è sulla rete
  `napay_local_browser` e raggiunge `http://napay-local-web` in chiaro,
  scavalcando gateway e TLS. Vedi la sezione "Rete e TLS".

#### Implementazione proposta

- Modulo `posapi` con `yii\rest\Controller`: risposta JSON, nessuna sessione e
  nessun cookie (`user.enableSession = false`), quindi niente CSRF browser da
  disattivare. Nessun header CORS. Regole URL esplicite e solo `POST`.
- La verifica delle credenziali riusa `LoginForm` (formato email, ricerca
  univoca, password, stato). Senza utente si esegue comunque una verifica bcrypt
  fittizia, per non rivelare l'esistenza dell'email con i tempi di risposta
  (correzione valida anche per il login web).

#### Autenticazione del servizio POS (obbligatoria, prima delle credenziali)

- Header `X-POS-Client-Key: <chiave>`: 32 byte casuali in base64url, generati
  fuori dal repository.
- Napay conserva solo i digest: `POS_API_CLIENT_KEYS_SHA256=<hex>[,<hex>]`.
  Confronto con `hash_equals`. Due digest permettono la rotazione senza fermo.
- Variabile vuota o assente: API disattivata (fail secure, `503 backend_unavailable`).
- La sessione è legata al client che l'ha creata (prefisso del digest della
  chiave). Rimuovere una chiave invalida anche le sue sessioni.
- **Δ** In alternativa c'è mTLS: più forte, ma richiede CA client e gestione
  dei certificati su Caddy. Proposta: chiave + rete dedicata + TLS verificato
  ora, mTLS valutabile in seguito.

#### Richiesta

- `Content-Type: application/json` obbligatorio; corpo massimo 4 KB.
- Un oggetto con esattamente due campi, `{"email": string ≤254, "password": string 1..1024}`.
  Campi in più, tipi diversi (array, numeri, null) e JSON non valido danno 400.
- **Δ** Header facoltativo `X-POS-Operator-IP`: IP dell'operatore al banco,
  accettato solo da un client autenticato e validato come IP. Serve solo per
  rate limit e audit.

#### Risposta 201

```json
{"access_token":"napos_<43 caratteri base64url>","token_type":"Bearer",
 "expires_at":"2026-11-11T23:00:00Z","operator":{"display_name":"Nome Cognome"}}
```

- **Δ** Niente `operator.id`. L'ID utente è interno, `users` non ha un UUID e il
  POS non ne ha bisogno. Se servisse un riferimento stabile si aggiunge in un
  passo successivo.
- Header di risposta: `Cache-Control: no-store`, `Pragma: no-cache`,
  `X-Content-Type-Options: nosniff`, nessun `Set-Cookie`.

#### Token e sessione

- Token opaco: `napos_` seguito da 32 byte casuali (`random_bytes`) in base64url.
  Il prefisso serve a riconoscerlo con lo scanning dei segreti. Niente JWT.
- Nel DB solo `SHA-256(token)` (univoco), nella nuova tabella
  `pos_operator_sessions`:
  - `user_id`, `client_key_prefix`, `credential_fingerprint` (digest dell'hash password);
  - `created_at`, `expires_at`, `last_used_at`, `revoked_at`, `revoked_reason`, `created_ip`.
- **Δ** Durata: scadenza assoluta di 12 ore (un turno), senza rinnovo
  automatico. Configurabile con `POS_SESSION_TTL_SECONDS` (massimo 24 ore).
- Revoca effettiva:
  - logout (`DELETE /sessions`, passo successivo);
  - scadenza;
  - utente disattivato o bloccato;
  - cambio o reset della password (cambia l'impronta);
  - chiave client rimossa;
  - revoca dal backoffice (passo successivo).
- Il login non concede accesso a negozi o POS: le assegnazioni esplicite le
  verificano le API successive.

#### Errori (stesso schema `{"error":{"code","message"}}`, messaggi fissi, `no-store`)


| Caso | HTTP | code |
| --- | --- | --- |
| Chiave servizio assente, errata o rimossa | 401 | `unauthenticated` |
| JSON non valido, campi mancanti o in più, tipi errati, corpo > 4 KB, Content-Type errato | 400 | `validation_failed` |
| Password errata, email inesistente, ambigua, account non attivo | 401 | `invalid_credentials` (identico in tutti i casi) |
| Troppi tentativi | 429 | `rate_limited` + `Retry-After` |
| API non configurata, DB non disponibile | 503 | `backend_unavailable` |
| Metodo diverso da POST | 405 | (risposta del framework, senza dettagli) |

#### Rate limit (cache + mutex, come `EmailRequestForm`)

- Per chiave client: 60 tentativi al minuto.
- Per IP operatore (`X-POS-Operator-IP`, oppure IP del chiamante): 10 al minuto.
- Per account (digest dell'email): 5 fallimenti in 15 minuti; poi 429 per
  quell'email fino alla fine della finestra. Un login riuscito azzera il contatore.
- I limiti sono verificati prima della password. Nel log non finiscono email in
  chiaro: si usano solo i digest come chiavi di cache.

#### Audit (registro attività, nessun segreto)

- Successo: evento attività con utente e prefisso del client.
- Fallimento: evento di sicurezza con l'email quotata (`Log::quote`) e il motivo
  interno generico. Mai password, token o chiave. URL senza query.

#### Rete e TLS per il server POS

- Il POS chiama `https://napay.local/api/pos/v1/sessions` **attraverso il
  gateway**, verificando la CA locale di Caddy (`caddy-root.crt`) e l'hostname.
  Niente `verify=false` e nessun redirect seguito.
- **Correzione necessaria nel repo POS** (agente POS): togliere il container POS
  da `napay_local_browser` e metterlo su una rete propria condivisa solo con il
  gateway (`pos_local_browser`). Sulla rete del POS il gateway avrà l'alias
  `napay.local`. Da parte Napay: gateway su entrambe le reti e rotta `/api/pos/*`.
- Variabili del server POS:
  - `NAPAY_API_BASE_URL=https://napay.local/api/pos/v1`
  - `NAPAY_POS_CLIENT_KEY=<chiave>` (env privato)
  - `NAPAY_CA_FILE=<caddy-root.crt>`
  - timeout 5 secondi, risposta massima 16 KB.
- Variabili Napay:
  - `POS_API_CLIENT_KEYS_SHA256`
  - `POS_SESSION_TTL_SECONDS` (facoltativa)
  - `TRUSTED_PROXIES` (già presente)

#### Test previsti (DB isolato della suite runtime)

- Login valido.
- Password errata, account inesistente, disattivato, ambiguo: tutti con lo
  stesso 401 e lo stesso corpo.
- Chiave assente, errata e rimossa; API non configurata.
- JSON malformato, array, campi in più, dimensioni eccessive.
- Rate limit per client, per IP e per account, con `Retry-After`.
- Token salvato solo come digest; scadenza; revoca per disattivazione e cambio password.
- Nessun `Set-Cookie`, nessun CORS, `no-store`.
- Nessun segreto in risposte, registro e log su file.

### Implementazione backend del login (2026-11-11) e handoff all'agente POS

Implementato come approvato. Commit:
- napay `be6b2bd5`: verifica bcrypt anche per email inesistente;
- napay `b79ae7ab`: endpoint, sessioni e test;
- orchestratore `d3656e6`: rete e gateway.

#### Chiamata

```http
POST https://napay.local/api/pos/v1/sessions
Content-Type: application/json
X-POS-Client-Key: <chiave client, 43 caratteri base64url>
X-POS-Operator-IP: <IP del browser dell'operatore>   (facoltativo, consigliato)

{"email":"operatore@example.it","password":"..."}
```

- **201**: `{"access_token":"napos_…","token_type":"Bearer","expires_at":"YYYY-MM-DDTHH:MM:SSZ","operator":{"display_name":"…"}}`
- **Errori**: `{"error":{"code":"…","message":"…"}}`.
  - 401 `unauthenticated`: chiave del servizio.
  - 401 `invalid_credentials`: credenziali o account.
  - 400 `validation_failed`.
  - 429 `rate_limited` con `Retry-After`.
  - 503 `backend_unavailable`.
  - 405 su metodi diversi da POST.
- Le risposte non hanno mai `Set-Cookie` né header CORS, e portano sempre
  `Cache-Control: no-store`.
- Il corpo deve contenere esattamente `email` e `password`, entrambe stringhe;
  massimo 4 KB.

#### Lato server POS

- Variabili:
  - `NAPAY_API_BASE_URL=https://napay.local/api/pos/v1`
  - `NAPAY_POS_CLIENT_KEY`: in locale è il file privato
    `/var/www/documents/progetti/napoliblockchain/napay/ambiente-locale/pos-client-key` (0600, ignorato da git), da montare come secret;
  - `NAPAY_CA_FILE`: CA locale Caddy, `/var/www/documents/progetti/napoliblockchain/napay/ambiente-locale/caddy-root.crt`.
- TLS sempre verificato (CA e hostname). Timeout 5 secondi, risposta massima
  16 KB, nessun redirect seguito.
- Il token va solo nella sessione server POS: mai nel browser, nell'URL o nei log.
- **Rete (bloccante, repo POS):** il container POS deve passare dalla rete
  `napay_local_browser` alla rete `pos_local_browser` (esterna, creata da
  `start-localhost.sh`, subnet 10.251.0.0/24). Lì il gateway ha l'alias
  `napay.local`. Il gateway accetta `/api/pos/*` solo da quella subnet (404 altrove).
  Finché il POS resta su `napay_local_browser` può raggiungere il web napay in
  chiaro, scavalcando TLS e gateway: va corretto prima dell'integrazione.
  Anche la rotta `pos.caddy` (`pos-v2-web`) deve funzionare sulla nuova rete.

#### Lato Napay

- `POS_API_CLIENT_KEYS_SHA256`: digest SHA-256 (hex) delle chiavi, separati da
  virgola, massimo 4. Più digest = rotazione: si aggiunge il nuovo, si aggiorna
  il POS, si toglie il vecchio, e le sessioni della chiave tolta decadono.
  Vuota o malformata: API disattivata.
- `POS_SESSION_TTL_SECONDS`: facoltativa, da 300 a 86400, default 43200 (12 ore).
- `TRUSTED_PROXIES`: il gateway, per ricavare l'IP reale del chiamante.

#### Durata e revoca

- Scadenza assoluta di 12 ore, senza rinnovo.
- La sessione non vale più se:
  - è revocata (`PosApi::revoke`);
  - l'utente è disattivato o bloccato;
  - la password cambia;
  - la chiave client viene rimossa;
  - la usa un client diverso da quello che l'ha creata.
- `DELETE /sessions` implementato nel micro-step logout sotto; revoca dal backoffice ancora successiva.
- Il login non dà accesso a negozi o POS: le assegnazioni le verificano le API successive.

#### Test eseguiti

- `tests/application/pos-sessions.php`: 62 controlli su DB isolato, nella
  suite runtime, con chiavi casuali per esecuzione.
- Suite runtime completa verde: HTTP 134, reset 68, attivazione 92,
  associazione 40, registro 20. Bootstrap 44, import 32.
- Prova end-to-end dalla rete `pos_local_browser` con HTTPS verificato:
  senza chiave o con chiave errata 401 `unauthenticated`, con la chiave valida
  401 `invalid_credentials`, senza CA rifiuto TLS. Dall'host `/api/pos/*` dà 404.
  Nel registro c'è l'IP del container POS e nessun segreto.

#### Allegati POS da allineare (repo `pos`, agente POS)

Micro-step client autorizzato dal handoff: solo login tramite l'endpoint
implementato, form con CSRF, TLS verificato, token in sessione server e scadenza
assoluta. Nessun catalogo fittizio, apertura POS o incasso. Correggere prima
la rete del POS come indicato sopra. Il logout, finche DELETE non e disponibile,
puo soltanto distruggere la sessione locale e deve dichiarare che non revoca il
token backend. La sessione locale non certifica grant o revoca remota continua.
Questa suddivisione non approva i contratti delle altre API ancora in bozza.

`pos/v2/docs/NAPAY-CONTRACT.md` e `pos-api.openapi.json` vanno aggiornati con
questo contratto:
- niente `operator.id`;
- header `X-POS-Operator-IP`;
- 405 sui metodi diversi da POST;
- `X-POS-Client-Key` confermato.

L'agente Napay non modifica il repo `pos`.

#### Esito micro-step client POS e percorsi locali (2026-11-11)

- Login reale POS/Napay collegato, senza catalogo, aperture o incassi;
  token solo nella sessione server, logout esplicitamente soltanto locale.
- Rete POS passata alla sola `pos_local_browser`; CA/hostname verificati,
  timeout 5 secondi, risposta massima 16 KiB, nessun redirect.
- Allegati POS allineati al login definitivo; altre sei operazioni ancora bozze.
- Stato privato configurabile con `POS_LOCAL_STATE`, sorgenti Napay con
  `NAPAY_LOCAL_STATE`, runtime con `POS_LOCAL_DATA`, senza percorsi personali
  nel codice. Valori locali e procedura nel README POS. File privati ignorati
  da Git, permessi 0700/0600; chiave cookie preesistente conservata.
- Runtime copiato a POS fermo nel percorso esterno; volume originale conservato.
- Eseguiti: 18 controlli importi, 13 configurazione, 37 client/sessione simulati,
  2 trasporto TLS reale, 7 percorsi privati, 24 browser anteprima e 21 browser
  con login API reale. Nessun test di lock o autorizzazione negozi dichiarato.

### Micro-step logout centrale approvato (2026-11-11)

L'utente autorizza l'agente POS a implementare anche le API Napay, con commit
separati e senza intervenire sui file condivisi dell'altro agente.

- `DELETE /api/pos/v1/sessions`, solo server-to-server: `X-POS-Client-Key`
  e `Authorization: Bearer napos_<43 caratteri base64url>`, corpo vuoto.
- Client autenticato prima di usare il bearer. Chiave assente/errata: 401
  `unauthenticated`; bearer assente/malformato: 401 `invalid_token`; corpo non
  vuoto: 400 `validation_failed`; limite 60/min per client e operazione: 429
  `rate_limited` con `Retry-After`; configurazione/DB indisponibile: 503
  `backend_unavailable`. Messaggi fissi, nessun token o chiave nei log.
- Aggiornamento atomico per digest token, prefisso client e `revoked_at IS NULL`:
  revoca definitiva con motivo `logout`, senza dipendere da utente ancora attivo
  o password invariata. Nessuna modifica ad altre sessioni.
- 204 senza corpo anche per replay, token scaduto, ignoto o appartenente ad
  altro client: nessun oracolo sull'esistenza; una chiave diversa non revoca
  il token. Audit solo per una revoca effettivamente registrata.
- Nessun cookie/CORS, `no-store`, TLS e limiti del client invariati. Altri
  metodi oltre POST/DELETE: 405. Nessuna apertura esistente da rilasciare in
  questa fase; il futuro rilascio atomico dei lock richiede il relativo SIP.
- POS elimina la propria sessione solo dopo 204 verificato. In caso di timeout,
  errore o risposta inattesa mostra errore generico, mantiene la custodia locale
  e consente retry. Sessione locale gia assente/scaduta: ritorno al login.
- File backend coinvolti: controller API `SessionsController`, nuova action
  `DeleteSessionAction`, test `pos-sessions.php` e nuovo `pos-logout.php`.
  Riutilizzati autenticazione, rate limit e modello sessioni esistenti; nessuna
  migration o modifica a configurazione/routing globale, Users o bootstrap.
- Test richiesti: revoca reale su DB isolato, replay, concorrenza/idempotenza,
  sessioni di altri client intatte, token scaduti/account cambiati, metodi,
  errori/limiti, assenza segreti, retry POS e logout browser con CSRF.

#### Esito e handoff all'altro agente Napay

- Implementato `DELETE /sessions` senza modificare `PosApi.php`, configurazione
  globale, modelli condivisi o file del lavoro PayPal/associazione.
- Il controller API esistente smista DELETE alla nuova `DeleteSessionAction`;
  la rotta pubblica resta invariata. Il commento storico in `config/web.php`
  che parla di solo POST e superato: POST e DELETE sono accettati; altri metodi 405.
- API verificate con 62 controlli login e 32 logout HTTP/DB su copia isolata,
  incluse due richieste concorrenti e DB temporaneamente indisponibile nella
  sola fixture. La suite esistente `pos-sessions.php` include `pos-logout.php`:
  nessuna modifica al runner condiviso richiesta.
- Client POS: 18 test simulati logout/controller (custodia su errore e retry),
  37 regressioni login/sessioni, 22 browser login/logout reale con TLS/CSRF,
  24 browser anteprima, 18 importi, 13 configurazione e 2 trasporto TLS.
- OpenAPI/README/contratto POS aggiornati: due operazioni disponibili, cinque
  bozze. Nessun catalogo o lock implementato, nessuna migration nuova.
- Nessun riavvio di Napay o gateway; ricostruito solo POS. Resta da progettare
  il prossimo micro-step catalogo/assegnazioni e poi aperture esclusive.

### Prossimo micro-step: catalogo autorizzato (BOZZA, da approvare)

Ricognizione del 2026-11-11, successiva al logout. Questa sezione e solo
documentazione: non approva migration, endpoint, grant o import di dati.

#### Decisioni confermate dall'utente (2026-11-11)

- Ogni operatore POS appartiene a un solo merchant e puo essere assegnato
  esplicitamente a piu negozi di quel merchant. Vietati grant verso negozi di
  altri merchant, anche se l'operatore conosce gli ID. L'appartenenza al merchant
  da sola non abilita automaticamente tutti i suoi negozi.
- Prima dell'apertura esclusiva il catalogo mostra disponibilita **Non
  verificata**, valore API `availability: "unknown"`. Non restituire `available`
  o `in_use` senza un registro autorevole delle aperture; nessuna apertura
  abilitata in questa fase. Gli stati futuri richiedono aggiornamento del contratto.
- Queste conferme chiudono le due scelte funzionali, non approvano ancora
  schema/migration, contratto GET completo o gestione backoffice.

#### Evidenze repository e schema locale

- Esistono `models/Stores.php` (`stores.merchant_id`, `description`),
  `Merchants.php` (`merchants.user_id`) e `Users::getMerchants()`. Quest'ultima
  relazione identifica aziende possedute, non negozi assegnati a operatori base.
  `Users::$merchant_id` e un attributo pubblico: non prova un grant persistente.
- Non trovati modelli/migration di assegnazione esplicita utente-negozio,
  modello `Pos.php` o tabella terminali nella v2 esaminata. Il riferimento a
  `app\models\Pos` in `StoresController.php` e residuo, non implementazione riusabile.
- Verificati in sola lettura i metadati della sandbox attiva: tabelle pertinenti
  `stores`, `storesettings`, `pos_operator_sessions`; non risultano tabelle POS
  o assegnazioni. Non letti record utente, dump o credenziali. La verifica
  riguarda questa sandbox, non certifica ogni dataset legacy disponibile.
- `storesettings.bps_storeid` identifica uno store BTCPay: non e un terminale
  POS Napay, non concede accesso e non deve diventare credenziale operatore.
- Riutilizzare `PosApi::authenticateClient/findActiveSession/throttle` e il
  modulo `posapi`. Non duplicare autenticazione, impronta password o rate limit.
- La precedente bozza `availability=available|in_use` e superata, per il primo
  catalogo, dalla scelta `unknown`: senza registro delle aperture non e
  possibile dichiarare correttamente la disponibilita.

#### Scomposizione proposta

1. **C1 - Fondazioni dati.** Dopo approvazione, nuova migration additiva per
   terminali Napay, appartenenza operatore-merchant e grant operatore-negozio:
   `pos_terminals`, `pos_operators`, `pos_store_operators`; AR dedicati, senza
   aggiungere relazioni ai modelli condivisi. Riutilizzare `users`, `stores`
   e `merchants`, mai ricreare anagrafiche o hash password.
2. **C2 - API in sola lettura.** `GET /api/pos/v1/terminals`, autenticazione
   servizio + bearer, ricontrollo sessione e grant a ogni richiesta. Scope
   prima di ordinamento/paginazione. Utente senza grant: 200 con lista vuota.
   Nessuna apertura o concessione implicita per ruolo admin/merchant/base.
3. **C3 - Vista POS.** Client server-to-server e lista `descrizione negozio -
   nome POS`, gestione vuoto/errore/sessione invalidata. Nessun pulsante che
   dichiari di aprire il terminale prima dell'API di apertura esclusiva.
4. **C4 separato - Gestione dati dal backoffice.** Definire CRUD terminali e
   assegnazioni con admin/merchant proprietario, autorizzazione record-level,
   POST/CSRF e audit. Non considerarlo implicitamente incluso nel GET.

Schema C1 finalizzato nella sezione seguente. Revoca grant effettiva dalla
richiesta API successiva; nessun SIN, wallet o apertura nella tabella grant.
Nessun seed automatico di autorizzazioni nel DB operativo: fixture solo nel DB
usa-e-getta. Tabelle nuove inizialmente vuote, senza assumere che ogni negozio
debba avere un POS o che il proprietario merchant sia automaticamente operatore.
Non modificare vecchie migration e non importare il legacy in questa fase.

#### C1 - Schema e vincoli finalizzati (2026-11-11)

Perimetro: schema documentato su richiesta dell'utente, **nessuna migration
ancora implementata o eseguita**. C2/GET, backoffice C4 e bootstrap sullo stack
condiviso restano gate separati.

Metadati verificati in sola lettura sulla sandbox MySQL 8.4.13: `users.id`,
`merchants.id`, `merchants.user_id`, `stores.id` e `stores.merchant_id` sono
`INT` signed e NOT NULL. Gli indici attuali su `stores` sono PK `(id)` e indice
non univoco `(merchant_id)`; manca la chiave candidata `(id, merchant_id)`.
Questa rilevazione non sostituisce il preflight sul DB destinatario della migration.

**Convenzioni comuni.** Tre nuove tabelle InnoDB, utf8mb4 con collation
`utf8mb4_0900_bin`, coerente con le sessioni POS. Tutti i campi sotto sono NOT
NULL. ID referenziati `INT` signed, senza cambiare tipi nelle tabelle esistenti.
Flag `is_enabled` TINYINT con CHECK `IN (0,1)`, default 0: inserire una riga non
abilita nulla automaticamente. `created_at` e `updated_at`: BIGINT signed,
Unix UTC in secondi, CHECK non negativi e `updated_at >= created_at`; valori
impostati dal servizio, non dal browser. Tutte le FK nuove sono
`ON DELETE RESTRICT ON UPDATE RESTRICT`: niente trasferimenti o cancellazioni
a cascata del dominio POS. Indici di supporto FK espliciti e nominati.

| Tabella | Colonne | Chiavi e indici |
| --- | --- | --- |
| `pos_operators` | `user_id INT`, `merchant_id INT`, `is_enabled TINYINT`, `created_at BIGINT`, `updated_at BIGINT` | PK `(user_id)`; UNIQUE `(user_id, merchant_id)` per FK composite; INDEX `(merchant_id)`; FK `user_id -> users.id`, `merchant_id -> merchants.id`. |
| `pos_store_operators` | `user_id INT`, `merchant_id INT`, `store_id INT`, `is_enabled TINYINT`, `created_at BIGINT`, `updated_at BIGINT` | PK `(user_id, store_id)`; INDEX `(user_id, merchant_id)`; INDEX `(store_id, merchant_id)`; FK `(user_id, merchant_id) -> pos_operators(user_id, merchant_id)` e `(store_id, merchant_id) -> stores(id, merchant_id)`. |
| `pos_terminals` | `id INT AUTO_INCREMENT`, `public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin`, `merchant_id INT`, `store_id INT`, `name VARCHAR(256)`, `is_enabled TINYINT`, `created_at BIGINT`, `updated_at BIGINT` | PK `(id)`; UNIQUE `(public_id)`; INDEX `(store_id, merchant_id)`; INDEX `(store_id, is_enabled, id)`; FK `(store_id, merchant_id) -> stores(id, merchant_id)`. |

Unica modifica strutturale a tabella esistente: aggiungere a `stores` UNIQUE
`(id, merchant_id)`, nome riservato `uq-pos-stores-id-merchant`. `id` e gia PK:
nessun nuovo vincolo funzionale sui dati esistenti; serve come chiave candidata
esplicita delle FK composite. Non rimuovere gli indici esistenti. La migration
deve verificare un eventuale indice equivalente prima di crearne un duplicato;
collisione del nome con definizione diversa = errore controllato, non DROP.

`merchant_id` in grant e terminali e ridondanza intenzionale, non un nuovo
input di autorizzazione: deriva dall'appartenenza/negozio lato server. Le FK
composite ne impongono la coerenza anche a scritture concorrenti o fuori dal
form. Non basta confrontarlo nel controller.

`public_id`: UUID v4 canonico minuscolo generato dal server con casualita
crittografica; immutabile, non SIN e non credenziale. CHECK lunghezza 36 e
validazione formato/versione nel modello. Non esporre `id`, `merchant_id` o
`store_id` come prova di autorizzazione. `name`: CHECK
`CHAR_LENGTH(TRIM(name)) > 0`, validazione Yii2 stringa/max 256 e normalizzazione
degli spazi esterni nel servizio. Non imporre nuove unicita sui nomi: la chiave
stabile e `public_id`; etichette non sono credenziali o identificatori univoci.

**Invarianti e ciclo di vita.**

1. PK `pos_operators.user_id`: un solo merchant per account operatore, anche
   con zero grant o profilo disabilitato. Nessun merchant ricavato dal primo grant.
2. FK composite: ogni grant riferisce sia l'operatore sia un negozio del suo
   stesso merchant; ogni terminale appartiene coerentemente a un negozio.
   Il vincolo resta valido anche per righe disabilitate.
3. Lettura futura: sessione valida, account valido, profilo operatore abilitato,
   grant abilitato e terminale abilitato, tutti sul medesimo merchant/negozio.
   Nessun bypass admin/merchant; profilo o grant mancante produce catalogo vuoto,
   non errore e non concessione implicita. Errori DB/schema restano 503.
4. Revoca ordinaria = disabilitazione del profilo/grant/terminale, con audit;
   niente cancellazione automatica. Revoca dell'ultimo grant non elimina
   `pos_operators` e non libera implicitamente l'appartenenza al merchant.
5. Le FK bloccano cambio merchant dell'operatore o del negozio finche esistono
   riferimenti incompatibili, anche disabilitati. Nessun `ON UPDATE CASCADE`.
   Questo puo bloccare anche DELETE/cascade di vecchi CRUD: effetto intenzionale
   da segnalare al backoffice, non da aggirare disattivando i controlli FK.
6. Riassegnazione tra merchant fuori da C1-C3: servira un comando amministrativo
   esplicito e autorizzato, transazionale e con audit, che gestisca prima grant
   incompatibili e revoca di tutte le sessioni POS dell'operatore, poi la nuova
   appartenenza. Nessuna riattivazione delle vecchie autorizzazioni o sessioni.
   Futuri lock/storico richiederanno ulteriori verifiche prima del trasferimento.
7. Terminali non trasferibili automaticamente a un altro negozio/merchant.
   Disabilitare non cambia identita. Trasferimento e trattamento dello storico
   fuori perimetro; non riusare UUID dismessi per altri terminali.
8. Nessuna colonna `availability`, lock, SIN o wallet in C1. Nel catalogo iniziale
   `unknown` e valore di presentazione, non disponibilita persistita o acquisita.

**Migration e test prima dell'applicazione.** Una sola nuova migration C1, con
timestamp da riservare dopo quelle dell'altro agente; AR nuovi `PosOperators`,
`PosStoreOperators`, `PosTerminals`. Nessun edit a Users/Stores/Merchants.
Preflight: MySQL supportato, engine, tipi, indice candidato e assenza di tabelle
omonime incompatibili; non correggere in silenzio schema o righe preesistenti.
Ordine: indice `stores`, `pos_operators`, `pos_terminals`, `pos_store_operators`
con relativi vincoli. Non fingere atomicita completa del DDL MySQL: i passi
possono essere gia applicati dopo un errore. Riesecuzione solo dopo verifica
delle definizioni presenti, senza DROP/TRUNCATE o seed automatici.
Rollback distruttivo automatico disabilitato come per le sessioni POS: backup
e procedura approvata prima di eliminare strutture contenenti dati.

Test su DB usa-e-getta: inserimenti validi multi-negozio nello stesso merchant;
duplicato operatore/UUID/grant rifiutato; FK inesistenti e grant cross-merchant
rifiutati; flag e nomi vuoti non validi rifiutati; due assegnazioni concorrenti
verso merchant diversi non producono doppia appartenenza; riassegnazioni e
DELETE di parent con riferimenti bloccati; grant disabilitato non rimuove
appartenenza; dati e schema non POS preservati; applicazione nuova, riesecuzione
bootstrap e gestione DDL parziale senza perdita dati. Solo dopo test e accordo
con l'altro agente potra essere migrata la sandbox condivisa.

#### Contratto GET da finalizzare prima di C2

- Chiave client e bearer come sessioni; risposta solo JSON, `no-store`, niente
  cookie/CORS; stessa rete e TLS. Il browser non riceve token o chiave servizio.
- Riutilizzare la bozza `{items, next_cursor}` con item
  `{id, store_name, name, availability}`; per questo micro-step `availability`
  vale soltanto `unknown`, presentato come "Non verificata" nella vista POS.
- `store_name` deriva da `stores.description`, non da ID o SIN. Nomi vuoti e
  limiti lunghezza vanno validati nei dati, output sempre codificato nel POS.
- `limit`: proposta default 50, massimo 100; `cursor` opaco e validato, legato
  allo scope del chiamante. Ricontrollare grant anche quando cambia il catalogo
  tra pagine; nessuna cache di autorizzazioni nel POS. Non promettere snapshot
  stabile o conteggi globali non necessari.
- Nessun `user_id`, `merchant_id` o `store_id` client come prova di accesso;
  niente filtri che allarghino lo scope. Proiettare solo i campi pubblici.
- 400 parametri non validi, 401 servizio/sessione non validi, 405 altri metodi,
  429 con Retry-After e 503 backend/schema indisponibile. Schema mancante non
  deve risultare un falso catalogo vuoto. Dettagli/codici e budget rate limit
  ancora da fissare; nessun payload definitivo implicito da questa bozza.
- Sessione invalidata: uscita dalla vista protetta; guasto temporaneo: errore
  generico, niente dati vecchi presentati come grant attuali.

#### Ownership file e conflitti potenziali

| File/area | Ownership proposta | Coordinamento |
| --- | --- | --- |
| Nuova migration dedicata POS, nome/timestamp da riservare | Agente POS/API | Concordare ordine con nuove migration dell'altro agente; il bootstrap le applica automaticamente. |
| Nuovi `models/PosOperators.php`, `PosTerminals.php`, `PosStoreOperators.php` | Agente POS/API | Schema C1 sopra; nessun edit a Users/Stores/Merchants. |
| Nuovi `modules/posapi/controllers/TerminalsController.php`, `components/pos/TerminalCatalog.php` | Agente POS/API | Prima verificare che nessun altro agente li stia creando. |
| Nuovo `tests/application/pos-terminals.php` e fixture dedicate | Agente POS/API | Non modificare fixture comuni mentre usate dall'altro agente. |
| `config/web.php` per la rotta GET | Condiviso, altro agente attivo | Serve una regola esplicita; riservare una modifica minima o consegnare patch all'altro agente. Nessun aggiramento nel modulo. |
| `components/pos/PosApi.php`, nuovo `components/Throttle.php` | Altro agente | Solo lettura/riuso; nuove modifiche richiedono accordo. |
| `tests/docker/runtime.sh` | Condiviso, altro agente attivo | Concordare una riga per la suite; in alternativa esecuzione isolata senza edit al runner. |
| `models/Users.php`, `Stores.php`, `Merchants.php`, relativi controller/menu | Condivisi | Non modificare in C1-C3; C4 richiede nuova assegnazione file. |
| `pos/v2` client/controller/vista catalogo e test | Agente POS | Nessuna modifica al backoffice per rendere funzionante la UI POS. |
| SIP-021 e allegati contratto/OpenAPI POS | Agente POS, handoff esplicito | Approvare prima, aggiornare gli allegati e solo dopo implementare. |

Situazione Git osservata: altro agente lavora su PayPal/associazione, routing
globale, throttling e runner runtime. File nuovi separati riducono conflitti
testuali, non eliminano dipendenze funzionali o effetti delle migration sullo
stesso stack. Non avviare bootstrap condivisi ne ricreare Napay durante C1-C3
senza coordinamento. Branch diversi nella stessa directory non isolano i file;
eventuali worktree separati richiedono anche stack/DB di test isolati.

#### Test e gate

- Migration su DB usa-e-getta, FK/unicita, dati esistenti preservati, replay
  bootstrap; nessuna scrittura sul DB della sandbox durante la progettazione.
- Utente assegnato a due negozi, negozi altrui esclusi; nessun grant = vuoto.
- Grant verso un altro merchant rifiutato; appartenenza univoca dell'operatore
  verificata anche in riassegnazioni e cambio merchant del negozio. Nessun
  accesso ampliato dopo revoca dell'ultimo grant. Disponibilita sempre `unknown`
  finche mancano i lock, senza pulsanti di apertura attivi.
- Ruolo base/merchant/admin senza grant non ottiene concessioni implicite.
- Grant revocato, terminale disabilitato, sessione scaduta/revocata, password
  cambiata e chiave rimossa: effetto alla richiesta successiva.
- Tentativi di scope/cursor manipolati, limiti, parametri ignoti, metodi e
  ordine stabile; dati di altri merchant non compaiono neppure nei conteggi.
- API non espone SIN/credenziali/wallet; nomi malevoli codificati nella vista;
  token solo sul server; browser mobile/desktop e nessun incasso/apertura.
- Regressioni login/logout e test di accesso cross-tenant sul DB reale di test.
- Prima del codice riservare migration e approvare implementazione C1 sullo
  schema finalizzato sopra. C2-C3 richiedono ancora rotta/runner, gestione
  iniziale terminali/grant e dettagli GET; non sono approvati implicitamente.

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

- Flusso server-to-server approvato; login centralizzato tramite redirect non
  scelto. Formato del token e autenticazione del servizio definiti nella sezione
  di implementazione backend; successive API ancora da concordare.
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
  `partial-backend-sessions-implemented`, login/logout disponibili; altre cinque operazioni bozze.
- [Stato e limiti preview](../pos/v2/README.md).
- Il test `pos/v2/tests/api-contract.cjs` controlla struttura e riferimenti
  della proposta, non e un test di integrazione del backend.
