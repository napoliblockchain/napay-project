# SIP-022 B1 - Provisioning merchant, negozi e POS su BTCPay (PROPOSTA)

- Autore: agente Napay. Data: 2026-11-12.
- Riferimenti: [SIP-022](../SIP-022-provisioning-merchant-store-pos-btcpay.md),
  [decisione P3](B0-DECISIONE-P3.md), [esiti B0](B0-ESITI.md),
  [SIP-023](../SIP-023-profili-soci-merchant-operatori.md) (R3b attivazione merchant),
  SIP-021 C1/C4 (negozi e terminali).
- Stato: **proposta da rivedere. Nessun codice B1**, nessun segreto generato,
  nessuna chiamata a BTCPay produzione o al regtest condiviso.
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
| `btcpay_merchant_accounts` | merchant, instance, `ref` casuale (16 byte hex), email tecnica `m-<ref>@btcpay-merchants.jamprojects.it`, id utente remoto, stato, segreto onboarding cifrato (password, temporaneo), chiave merchant cifrata, impronta della chiave (SHA-256), generazione chiave, tentativi di creazione chiave, ultimo codice errore, versione | UNIQUE (instance, merchant), UNIQUE ref, UNIQUE (instance, email), UNIQUE (instance, remote_user_id) |
| `btcpay_store_links` | negozio, account merchant, `marker` casuale, id store remoto, stato, versione | UNIQUE (instance, store), UNIQUE marker, UNIQUE (instance, remote_store_id) |
| `btcpay_pos_links` | terminale C1, store link, `marker`, id app remota, stato, versione | UNIQUE (instance, terminal), UNIQUE marker, UNIQUE (instance, remote_app_id) |
| `btcpay_provisioning_jobs` | outbox: tipo, entità, generazione, stato, tentativi, prossimo tentativo, lease (owner, scadenza), ultimo codice errore | UNIQUE (tipo, entità, generazione) |

Il `marker` entra nel nome remoto (es. `Negozio X · n7k2...`): non rende il
nome univoco su BTCPay, ma permette di riconoscere **la nostra** risorsa dopo
un timeout. Il merchant non usa l'interfaccia BTCPay, quindi il suffisso non
pesa sull'esperienza.

## 3. Stati e flusso

Stati comuni: `pending`, `running`, `retry_wait`, `reconcile_required`,
`failed`, `synced`. `synced` = risorsa remota associata, **non** incassi pronti.

### 3.1 Account merchant (checkpoint salvati dopo ogni successo remoto)

| Passo | Prima della chiamata | Chiamata | Esiti |
| --- | --- | --- | --- |
| A | genera `ref`, password casuale (32 byte), la cifra e la salva; stato `user_requested` | `POST /api/v1/users` (provisioner) | 201: salva id remoto, stato `user_created`. 422: vai a riconciliazione. 429: `retry_wait` con Retry-After. Timeout/5xx: riconciliazione. 401/403: `failed` (nessuna escalation). |
| A-r | — | `GET /api/v1/users/{email}` | 404: nessun utente, si può ripetere A con **la stessa** password salvata. 200: l'utente esiste; si adotta **solo** se la password salvata funziona in Basic (passo B riuscito), il che prova che l'abbiamo creato noi; altrimenti `reconcile_required`. Mai reset o modifica di un utente esistente. |
| B | incrementa e salva `generazione` e `tentativi chiave`; label `napay-<ref>-g<generazione>` | `POST /api/v1/api-keys` (Basic del merchant) | 200: cifra e salva la chiave e la sua impronta, stato `key_saved`. 401 (password non valida): `reconcile_required`. 429/timeout: `retry_wait`, ma **al massimo 3 generazioni**: poi `reconcile_required` (chiavi orfane possibili). |
| C | — | `GET /api/v1/stores` con la nuova chiave | 200: cancella il segreto onboarding (password), stato `synced`. |

Crash tra B e salvataggio: la chiave esiste su BTCPay ma non in Napay. Al
riavvio il passo B riparte con una nuova generazione (limite 3); le chiavi
orfane hanno label riconoscibile e si rimuovono a mano dall'admin BTCPay.
Da verificare in B1: se un utente può elencare/revocare le proprie chiavi via
API; se sì, il recupero revoca le orfane invece di tollerarle.

### 3.2 Store e app POS

| Passo | Chiamata (chiave del merchant) | Esiti |
| --- | --- | --- |
| Store | `POST /api/v1/stores` con nome + marker | 200: salva id, `synced`. Timeout/5xx: `GET /api/v1/stores`, cerca il marker: **uno** = adotta; **zero** = si può ripetere; **più di uno** = `reconcile_required`. 403/401: `failed` e account in revisione. |
| App POS | `POST /api/v1/stores/{id}/apps/pos` con nome + marker | come sopra con `GET /api/v1/stores/{id}/apps`. |

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
- 429: attesa = `Retry-After` (massimo 300 s), poi backoff con jitter;
  massimo tentativi per lavoro (es. 10), poi `failed` con codice.
- Eventi creati nella stessa transazione locale che attiva il merchant (R3b)
  o crea negozio/terminale: nessuna chiamata BTCPay nel salvataggio anagrafico.

## 5. Segreti

- **Cifratura a busta**: per ogni segreto una chiave dati casuale (32 byte);
  segreto cifrato con XChaCha20-Poly1305 (`sodium`, già disponibile in
  PHP 8.3 dell'immagine Napay) con dati associati = tabella, id, merchant,
  instance, scopo; chiave dati cifrata con la chiave master (KEK).
- KEK fuori da DB e git, in un file secret del solo worker, con identificativo
  di versione salvato accanto a ogni segreto; mai `COOKIE_VALIDATION_KEY` o
  `SECRET_HASH_KEY`.
- Rotazione KEK: comando che ricifra solo le chiavi dati (i segreti restano).
- Password di onboarding: esiste solo tra passo A e C, cifrata; cancellata
  quando la chiave del merchant è salvata e verificata.
- Nessun segreto in outbox, errori, audit, log o argomenti di processi.

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
- 429 con Retry-After; servizio spento; timeout ambiguo con marker zero/uno/due;
- utente con la stessa email creato fuori da Napay: mai adottato né resettato;
- chiave revocata: lavori sospesi, merchant non disattivato;
- nessun segreto in DB in chiaro, log, outbox, errori, processi;
- trasporto via proxy/TLS sullo stack del master (punto 9).

## 9. File (da assegnare dal master)

Nuovi, nel dominio provisioning: modelli dei mapping e dell'outbox,
`components/btcpay/provisioning/*` (client, cifratura, worker), comando
console, migration (timestamp del master), test e runner dedicati.
Condivisi (master): attivazione merchant R3b, creazione negozi
(`StoresController`, oggi con il vecchio `createStore` sincrono da sostituire),
terminali C4, servizio worker nello stack, secret della KEK, egress/CA.

## 10. Decisioni richieste

- Master: review di questa proposta, schema e assegnazione file.
- Utente/master: rotazione della chiave merchant (sezione 6, proposta opzione 2).
- Master: destino del vecchio flusso sincrono `StoresController::actionCreate`
  e dei valori `settings.btcpayApiKey/btcpayHost` (non più usati da B1).
