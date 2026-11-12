# SIP-022 B1 - Provisioning merchant, negozi e POS su BTCPay (PROPOSTA)

- Autore: agente Napay. Data: 2026-11-12.
- Riferimenti: [SIP-022](../SIP-022-provisioning-merchant-store-pos-btcpay.md),
  [decisione P3](B0-DECISIONE-P3.md), [esiti B0](B0-ESITI.md),
  [SIP-023](../SIP-023-profili-soci-merchant-operatori.md) (R3b attivazione merchant),
  SIP-021 C1/C4 (negozi e terminali).
- Stato: **proposta da rivedere. Nessun codice B1**, nessun segreto generato,
  nessuna chiamata a BTCPay produzione o al regtest condiviso.
  Aggiornata dopo [review master](B1-REVIEW-MASTER.md) (RV1-RV5, sezione 11).
- Timestamp delle migration, file condivisi e servizio worker nello stack: master.

## 1. Perimetro

Napay è l'unico master. Per ogni merchant attivato (R3b) il worker crea su
BTCPay, nell'ordine:

1. **utente tecnico** del merchant (provisioner: `cancreateuser`,
   `canviewusers`);
2. **chiave del merchant**, creata dall'utente tecnico con la propria password
   casuale (Basic, solo su HTTPS verificato), limitata a
   `btcpay.store.canmodifystoresettings`;
3. **uno store per ogni negozio** Napay, creato con la chiave del merchant
   (merchant unico Owner, provisioner mai membro);
4. **un'app POS per ogni terminale** C1, sullo store del suo negozio.

Fuori perimetro: fatture e incassi (permessi separati, SIP futuro), wallet e
metodi di pagamento dello store, webhook BTCPay -> Napay, store legacy
(riconciliazione manuale già decisa), cancellazioni remote.

Evidenze B0 su cui si basa (BTCPay 2.4.7, `phase2.sh` 23 PASS):
- il provisioner non può creare store né amministratori (403, utente non creato);
- la chiave del merchant vede solo i propri store (altri: 403) e non crea chiavi;
- stessa email di nuovo: 422; creazione utenti limitata (429, `Retry-After: 10`);
- nomi di store/app non univoci; store inesistente = 403; nessun elenco delle
  chiavi di un utente visto nell'OpenAPI (da riverificare in B1).

## 2. Dati (schema proposto; migration e timestamp dal master)

Tutte le tabelle: InnoDB, utf8mb4_0900_bin, BIGINT Unix, FK RESTRICT, CHECK
sugli stati, nessuna colonna con segreti in chiaro. `instance` = identificativo
dell'istanza BTCPay (digest dell'URL configurato), così regtest e produzione
non si confondono mai.

| Tabella | Contenuto | Vincoli |
| --- | --- | --- |
| `btcpay_merchant_accounts` | merchant, instance, `ref` casuale (16 byte hex), email tecnica `m-<ref>@btcpay-merchants.jamprojects.it`, id utente remoto, stato, generazione chiave, tentativi di creazione chiave, ultimo codice errore, versione. **Nessun segreto.** | UNIQUE (instance, merchant), UNIQUE ref, UNIQUE (instance, email), UNIQUE (instance, remote_user_id) |
| `btcpay_merchant_credentials` | **una riga per segreto**: account (FK), tipo (`onboarding_password` o `api_key`), generazione, testo cifrato con tag, nonce del segreto, chiave dati cifrata, nonce della chiave dati, versione della KEK, impronta (solo per `api_key`, SHA-256) | PK (account, tipo); **leggibile e scrivibile solo dall'utente DB del worker** (sezione 5) |
| `btcpay_store_links` | negozio, account merchant, `marker` casuale, id store remoto, stato, versione | UNIQUE (instance, store), UNIQUE marker, UNIQUE (instance, remote_store_id) |
| `btcpay_pos_links` | terminale C1, store link, `marker`, id app remota, stato, versione | UNIQUE (instance, terminal), UNIQUE marker, UNIQUE (instance, remote_app_id) |
| `btcpay_provisioning_jobs` | outbox: tipo, entità (solo ID Napay), generazione, stato, tentativi, prossimo tentativo, lease (owner, scadenza), **operazione remota in volo** (tipo, inizio, owner), versione, ultimo codice errore. Nessun segreto nel payload. | UNIQUE (tipo, entità, generazione) |

Il `marker` entra nel nome remoto (es. `Negozio X · n7k2...`): non rende il
nome univoco su BTCPay, ma permette di riconoscere **la nostra** risorsa dopo
un timeout. Il merchant non usa l'interfaccia BTCPay, quindi il suffisso non
pesa sull'esperienza.

## 3. Stati e flusso

Stati comuni: `pending`, `running`, `in_flight`, `retry_wait`, `deferred`,
`reconcile_required`, `failed`, `synced`. `synced` = risorsa remota
associata, **non** incassi pronti. `in_flight` = il checkpoint è stato
salvato e una chiamata che crea qualcosa è partita: finché non si registra
un esito certo, quella risorsa non riceve un altro POST.

### 3.1 Account merchant (checkpoint salvati dopo ogni successo remoto)

| Passo | Prima della chiamata | Chiamata | Esiti |
| --- | --- | --- | --- |
| A | genera `ref`, password casuale (32 byte), la cifra e la salva; stato `user_requested` | `POST /api/v1/users` (provisioner) | 201: salva id remoto, stato `user_created`. 422: vai a riconciliazione. 429: `retry_wait` con Retry-After. Timeout/5xx: riconciliazione. 401/403: `failed` (nessuna escalation). |
| A-r | — | `GET /api/v1/users/{email}` | 404: nessun utente, si può ripetere A con **la stessa** password salvata. 200: l'utente esiste; si adotta **solo** se la password salvata funziona in Basic (passo B riuscito), il che prova che l'abbiamo creato noi; altrimenti `reconcile_required`. Mai reset o modifica di un utente esistente. |
| B | incrementa e salva `generazione` e `tentativi chiave`; label `napay-<ref>-g<generazione>` | `POST /api/v1/api-keys` (Basic del merchant) | 200: cifra e salva la chiave e la sua impronta, stato `key_saved`. 401 (password non valida): `reconcile_required`. 429: `deferred` (sezione 4). Timeout: una nuova generazione è ammessa (una chiave in più non crea risorse né accessi a store altrui), **al massimo 3 generazioni**: poi `reconcile_required` (chiavi orfane possibili). |
| C | — | `GET /api/v1/stores` con la nuova chiave | 200: cancella il segreto onboarding (password), stato `synced`. |

Il passo A si può ripetere senza duplicare: BTCPay rifiuta la stessa email
(422, dimostrato in B0) e la riconciliazione A-r prova la proprietà con la
password. Store e app **non** hanno questa garanzia (sezione 3.2).

Crash tra B e salvataggio: la chiave esiste su BTCPay ma non in Napay. Al
riavvio il passo B riparte con una nuova generazione (limite 3); le chiavi
orfane hanno label riconoscibile e si rimuovono a mano dall'admin BTCPay.
Da verificare in B1: se un utente può elencare/revocare le proprie chiavi via
API; se sì, il recupero revoca le orfane invece di tollerarle.

### 3.2 Store e app POS

| Passo | Chiamata (chiave del merchant) | Esiti |
| --- | --- | --- |
| Store | `POST /api/v1/stores` con nome + marker | 200: salva id, `synced`. Timeout, 5xx o esito sconosciuto: `reconcile_required`, poi `GET /api/v1/stores` periodici cercando il marker: **uno** = adotta (unico caso automatico); **zero** o **più di uno** = resta `reconcile_required`. 403/401: `failed` e account in revisione. |
| App POS | `POST /api/v1/stores/{id}/apps/pos` con nome + marker | come sopra con `GET /api/v1/stores/{id}/apps`. |

**Zero risultati non prova l'assenza** (RV1): la prima richiesta può essere
ancora in esecuzione e completarsi dopo il GET. Quindi nessun secondo POST
automatico per store e app. Le riletture periodiche possono solo **adottare**
il marker comparso in seguito. Un nuovo POST con **nuovo marker** richiede
un'azione esplicita dell'admin (registrata nel registro), dopo una finestra
minima dall'ultimo tentativo e con la rilettura che conferma zero risultati.
Se poi compaiono entrambi i marker, il secondo store resta orfano segnalato:
nessuna cancellazione automatica.

Ordine obbligato: account `synced` -> store -> app. Un negozio senza account
pronto resta `pending`, non fallisce.

## 4. Worker, concorrenza e ritentativi

- Comando console dedicato (es. `yii btcpay-provision/run`) in un servizio
  separato dal web, con accesso alla chiave provisioner e alla chiave di
  cifratura; web e POS non le vedono mai.
- Presa dei lavori: `SELECT ... FOR UPDATE SKIP LOCKED` sull'outbox, lease con
  scadenza; per ogni risorsa lock della riga di mapping e controllo di
  versione: **un solo lavoro attivo per risorsa**.
- Nessuna chiamata remota dentro una transazione DB: transazione breve per il
  checkpoint prima, chiamata, transazione breve per l'esito.
- **La lease non ferma un worker vecchio** (RV2): un worker scaduto può essere
  ancora dentro una chiamata. Quindi:
  - prima di ogni POST si registra `in_flight` (tipo, inizio, owner) con CAS
    su owner della lease e versione;
  - ogni esito si scrive solo con CAS su owner e versione: un worker scaduto
    non sovrascrive lo stato, e il suo esito tardivo viene scartato;
  - un lavoro trovato `in_flight` con lease scaduta **non** viene rilanciato:
    diventa `reconcile_required` e segue la riconciliazione del suo passo
    (A ripetibile, B nuova generazione nel limite, store/app solo adozione
    del marker).
- **429 e `Retry-After`** (RV4):
  - si accettano secondi interi non negativi o data HTTP (IMF-fixdate,
    RFC 9110); solo valori **non interpretabili** o assenti usano il backoff
    esponenziale da 30 s con jitter, massimo 1 ora. Un valore valido ma
    grande (es. secondi > 86400) **non** ricade nel backoff: vale la regola
    delle 24 ore sotto;
  - prossimo tentativo = il più tardo fra scadenza del server e backoff: mai
    una chiamata prima della scadenza indicata dal server;
  - scadenza oltre 24 ore: stato `deferred` che richiede l'admin, nessuna
    chiamata automatica;
  - il worker dorme fino al primo lavoro scaduto (nessun ciclo attivo);
    massimo tentativi per lavoro (es. 10), poi `failed` con codice.
- **Il worker non si fida del payload** (RV3): prima di ogni concessione
  remota rilegge dal DB entità, tenant e stato (merchant attivo e qualificato
  R1, negozio del merchant, terminale esistente del negozio). Payload =
  solo tipo e ID Napay.
- **Configurazione distinta dall'operatività**: i terminali C4 nascono
  disabilitati, quindi l'app POS si crea comunque alla creazione del
  terminale (configurazione). Abilitazione, grant e apertura restano controlli
  dell'operatività lato Napay (C1-C4), non condizioni del provisioning; un
  terminale disabilitato non blocca per sempre il suo lavoro.
- Eventi creati nella stessa transazione locale che attiva il merchant (R3b)
  o crea negozio/terminale: nessuna chiamata BTCPay nel salvataggio anagrafico.

## 5. Segreti

- **Cifratura a busta, una busta indipendente per ogni segreto** (RV5).
  Password di onboarding e chiave API sono righe separate, ciascuna con:
  - chiave dati (DEK) nuova di 32 byte, generata a ogni cifratura e mai
    riusata per un altro segreto o un'altra generazione;
  - segreto cifrato con XChaCha20-Poly1305 IETF (`sodium`, già disponibile
    nell'immagine Napay), nonce casuale di 24 byte, tag incluso nel testo
    cifrato;
  - DEK cifrata con la KEK con lo stesso algoritmo e un **proprio** nonce
    casuale di 24 byte;
  - dati associati che legano il valore al suo posto:
    segreto `napay-btcpay|v1|<instance>|<account id>|<tipo>|<generazione>`;
    DEK la stessa stringa più `|kek<versione>`. Una riga copiata su un altro
    account, tipo o generazione non si decifra; la rotazione della KEK cambia
    solo i dati associati della DEK, non quelli del segreto.
  - versione della KEK salvata nella riga; con nonce casuali di 24 byte la
    probabilità di collisione è trascurabile anche con molte cifrature.
- KEK fuori da DB e git, in un file secret del solo worker, con identificativo
  di versione salvato accanto a ogni segreto; mai `COOKIE_VALIDATION_KEY` o
  `SECRET_HASH_KEY`.
- Rotazione KEK: comando che decifra la DEK con la KEK vecchia e la ricifra con
  la nuova (nuovo nonce, nuova versione nei dati associati); i segreti non
  cambiano; righe non decifrabili = errore, mai sovrascritte.
- Password di onboarding: esiste solo tra passo A e C, cifrata; cancellata
  quando la chiave del merchant è salvata e verificata.
- Nessun segreto in outbox, errori, audit, log o argomenti di processi.
- **Utenti DB separati** (decisione dell'utente, 2026-11-12):
  - utente DB del **web** (RV3): **nessun privilegio** su
    `btcpay_merchant_credentials`; **solo `INSERT`** su
    `btcpay_provisioning_jobs`, così l'evento nasce nella stessa transazione
    di attivazione merchant (R3b), creazione negozio o terminale; `SELECT`
    solo delle colonne di stato necessarie al backoffice su mapping e outbox;
    nessun `UPDATE`/`DELETE` sulle tabelle B1. Anche il "riprova" dell'admin è
    un nuovo `INSERT` (nuova generazione), non una modifica;
  - utente DB del **worker**: lettura e scrittura su mapping, outbox e
    credenziali; sola lettura delle tabelle Napay che deve ricontrollare
    (merchant, utenti, negozi, terminali, profili); nient'altro;
  - le migration restano dell'utente proprietario dello schema (bootstrap),
    che concede i privilegi; nessun utente applicativo con GRANT o DDL.
  Così una falla nel web (SQL injection, lettura arbitraria) non arriva
  nemmeno ai valori cifrati, e il furto del DB senza KEK resta inutile.

## 6. Revoca e rotazione della chiave merchant

- Revoca: `DELETE /api/v1/api-keys/current` con la chiave stessa; lavori
  pendenti del merchant sospesi (`reconcile_required`), merchant Napay **non**
  disattivato per questo.
- **Rotazione: decisione aperta.** La chiave del merchant non può crearne
  altre (403, B0) e la password viene cancellata dopo il passo C. Opzioni:
  1. conservare la password cifrata (solo worker) per future rotazioni;
  2. rotazione solo tramite procedura amministrativa manuale su BTCPay
     (nuova password impostata dall'admin, poi passo B);
  3. accettare chiavi senza rotazione periodica, solo revoca + nuovo utente.
  Proposta: 2, coerente con la decisione P3 (password eliminata).

## 7. Trasporto

Solo tramite il proxy di uscita (allowlist host esatto:443), TLS verificato
con la CA configurata (in locale la CA del gateway per `btcpay.local`),
nessun redirect seguito, timeout di connessione e risposta, risposta massima
limitata. Riuso del client di `components/payments/BTCPay.php` (opzioni curl),
non un secondo SDK.

## 8. Gate prima del codice e test

Gate già dimostrati in B0 (usa-e-getta): provisioner senza store né admin;
chiave merchant isolata e senza creazione chiavi; 429; nomi non univoci.

Test B1 previsti (regtest usa-e-getta + DB usa-e-getta, worker reale):
- due merchant, due negozi ciascuno, terminali: risorse corrette e isolate;
- crash simulato dopo ogni successo remoto (A, B, store, app) e ripresa;
- due worker in parallelo sulla stessa risorsa: un solo effetto remoto;
- 429 con Retry-After in secondi e come data HTTP, valori non validi, oltre
  24 ore: nessuna chiamata prima della scadenza; servizio spento;
- timeout ambiguo su store/app con marker zero/uno/due: nessun secondo POST
  automatico, adozione solo con un marker; POST ritardato che compare dopo
  la rilettura viene adottato;
- worker con lease scaduta ancora in chiamata: esito tardivo scartato dal CAS,
  lavoro `in_flight` scaduto passato a riconciliazione, non rilanciato;
- busta: dati associati diversi (account, tipo, generazione, versione KEK)
  rendono il segreto non decifrabile; DEK e nonce mai riusati;
- utente con la stessa email creato fuori da Napay: mai adottato né resettato;
- chiave revocata: lavori sospesi, merchant non disattivato;
- nessun segreto in DB in chiaro, log, outbox, errori, processi;
- trasporto via proxy/TLS sullo stack del master (punto 9);
- utente DB del web: qualunque accesso a `btcpay_merchant_credentials`
  rifiutato; `INSERT` in outbox consentito dentro la transazione di R3b,
  negozio e terminale; `UPDATE`/`DELETE` su tabelle B1 rifiutati; utente
  del worker: accesso consentito; nessun privilegio GRANT o DDL agli utenti
  applicativi;
- payload manipolato (ID di altro merchant, terminale disabilitato): il
  worker rifiuta dopo la rilettura dal DB.

## 9. File (da assegnare dal master)

Nuovi, nel dominio provisioning: modelli dei mapping e dell'outbox,
`components/btcpay/provisioning/*` (client, cifratura, worker), comando
console, migration (timestamp del master), test e runner dedicati.
Condivisi (master): utenti DB e privilegi nel bootstrap/stack (oggi un solo
utente applicativo), attivazione merchant R3b, creazione negozi
(`StoresController`, oggi con il vecchio `createStore` sincrono da sostituire),
terminali C4, servizio worker nello stack, secret della KEK, egress/CA.

## 10. Decisioni richieste

Già decise dal master (review): il vecchio `createStore` sincrono sarà
sostituito nell'integrazione dell'outbox, mai usato come fallback; il worker
non legge `settings.btcpayApiKey/btcpayHost`, che non si eliminano senza
revisione dei dati.


- Master: review di questa proposta, schema e assegnazione file.
- Utente/master: rotazione della chiave merchant (sezione 6, proposta opzione 2).

## 11. Correzioni dopo la review master

| Punto | Correzione |
| --- | --- |
| RV1 duplicati dopo timeout | Zero marker non prova l'assenza: store/app restano `reconcile_required`, solo adozione automatica con un marker; nuovo POST solo con azione dell'admin (sezione 3.2). |
| RV2 lease e fencing | Stato `in_flight` prima del POST, CAS su owner e versione per ogni esito, in volo scaduto = riconciliazione, mai rilancio (sezione 4). |
| RV3 privilegi e outbox | Web: solo `INSERT` in outbox e `SELECT` degli stati, zero privilegi sulle credenziali; worker rilegge entità e tenant dal DB (sezioni 4 e 5). |
| RV4 Retry-After | Secondi o data HTTP, mai chiamate prima della scadenza, oltre 24 ore `deferred` con admin, nessun ciclo attivo (sezione 4). |
| RV5 busta | Una busta per segreto: DEK, nonce e DEK cifrata propri, dati associati con account, tipo, generazione e versione KEK (sezioni 2 e 5). |
