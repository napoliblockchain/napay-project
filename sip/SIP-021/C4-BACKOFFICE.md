# C4 - Backoffice terminali, operatori e grant (BOZZA, da approvare)

- Autore: agente Napay. Data: 2026-11-12.
- Riferimenti: SIP-021 (sezioni C1 e scomposizione), [handoff C1](C1-HANDOFF.md),
  [prompt](PROMPT-AGENTE-NAPAY.md), `napay/tests/application/POS-CATALOG.md`.
- Base: Napay `a3fd15f3`, branch `feature/v2-napay-backoffice-c4`.
- Stato: solo documento. Decisioni D1-D3 confermate dall'utente il 2026-11-12
  (sezione 4). Nessun codice finché il master non approva questo allegato e
  non riserva il timestamp della migration inviti.

## 1. Rilevazioni sul backoffice (base `a3fd15f3`)

- Ruoli da `privileges.level` (`components/User.php`): admin 50
  (`isAdministrator`), merchant 30 (`isMerchant`), base 0. Nessun RBAC Yii.
- Proprietà del merchant: `merchants.user_id`. `User::getMerchantId()` prende
  `merchants[0]`: con più merchant per utente la scelta è arbitraria. C4 non lo
  usa: lo scope del merchant è l'insieme dei `merchants.id` con
  `user_id` = utente corrente (vuoto = nessuna risorsa).
- Gli account nascono solo da registrazione pubblica (`SiteController::signup`,
  attivazione via email). L'admin crea il merchant scegliendo un utente base e
  lo promuove a merchant (`MerchantsController::create`).
  Nessun merchant può oggi creare o invitare account.
- Nella registrazione l'utente sceglie da sé `is_merchant` e ottiene il livello
  30 (senza riga `merchants`). Per C4 il livello merchant da solo non dà scope:
  serve la proprietà in `merchants`. Segnalato al master (punto 7).
- Rotte: `enablePrettyUrl` senza strict parsing, quindi `pos-management/<action>`
  funziona senza modificare `config/web.php`.
- Accessi negati già registrati dal filtro globale `AuditedAccessControl`; scritture
  con `Log::save(..., Log::TYPE_DATA)`; pager unico `components/web/LinkPager`.
- ID nelle URL: pattern `Crypt::encrypt` + decodifica tollerante
  (`decodeId` in `AssociationController`); la cifratura non è autorizzazione.
- Revoca sessioni POS: `PosApi::revoke(PosOperatorSessions, reason)`, per
  singola sessione; riusabile senza modificare `PosApi.php`.

## 2. Attori e scope

| Attore | Condizione | Scope |
| --- | --- | --- |
| Admin | `User::isAdministrator()` | tutti i merchant, negozi, operatori, terminali |
| Merchant | `User::isMerchant()` **e** almeno un `merchants.user_id` = sé | solo i propri merchant e i loro negozi |
| Altri (base, merchant senza `merchants`) | - | 403 su tutto il controller |

Lo scope si applica nella query prima di conteggi, ordinamento e paginazione,
e di nuovo su ogni action che riceve un identificativo. Un record fuori scope
risponde 404 come un record inesistente (nessun oracolo sull'esistenza).
Nessun grant implicito: né admin né merchant diventano operatori o ricevono
accesso a negozi per ruolo.

## 3. Funzioni

Controller `PosManagementController` (`/pos-management/...`) per admin e
merchant; controller `PosInvitationController` (`/pos-invitation/accept`) per
l'utente invitato.

| Action | Metodo | Admin | Merchant | Effetto |
| --- | --- | --- | --- | --- |
| `index` | GET | sì | sì | due schede: terminali e operatori, filtro per negozio |
| `terminal-create` | GET/POST | sì | sì | nome + negozio (solo negozi in scope); `merchant_id` dal negozio; nasce disabilitato |
| `terminal-update` | GET/POST | sì | sì | solo nome |
| `terminal-enable` / `terminal-disable` | POST | sì | sì | flag `is_enabled` |
| `invitation-create` | GET/POST | sì | sì | invito via email a diventare operatore di un merchant in scope (D1) |
| `invitation-revoke` | POST | sì | sì | annulla un invito in attesa |
| `operator-view` | GET | sì | sì | profilo + grant per negozio |
| `operator-enable` / `operator-disable` | POST | sì | sì | flag profilo; disable revoca subito le sessioni POS (D3) |
| `grant-create` | POST | sì | sì | grant verso un negozio dello stesso merchant dell'operatore; nasce disabilitato |
| `grant-enable` / `grant-disable` | POST | sì | sì | flag grant |

Elenco terminali: `negozio - nome POS`, stato, disponibilità sempre
**"Non verificata"**. Nessun pulsante di apertura, chiusura o sblocco.
Niente delete, trasferimento di terminali o riassegnazione di operatori a un
altro merchant (fuori perimetro come da C1).

Identificativi:
- terminale: `public_id` (UUID) nella URL, mai `id`/`store_id`/`merchant_id`;
- operatore: `user_id` cifrato con `Crypt`;
- grant: operatore cifrato + `store_id` cifrato.
Decodifica fallita, tipo non scalare o lunghezza eccessiva: 404.

## 4. Collegamento degli account operatore (decisioni dell'utente, 2026-11-12)

**D1 - Invito del merchant, accettato dall'intestatario dell'account.**
Il merchant non vede un elenco utenti e non può collegare un account con un ID
o un'email: l'appartenenza nasce solo dal consenso dell'utente invitato.

Invito (`invitation-create`, admin o merchant proprietario):
- campi: email e merchant (solo tra quelli in scope; preselezionato se uno solo);
- risposta sempre uguale, che l'account esista o no: nessun oracolo sugli utenti;
- token: 32 byte casuali in base64url, nel DB solo SHA-256; scadenza 72 ore;
- un nuovo invito per la stessa coppia merchant/email annulla quello in attesa;
- email (`Yii::$app->mailer`, template nuovi in `mail/`): link
  `/pos-invitation/accept?token=...`; se l'account non esiste, invita a
  registrarsi prima con quell'indirizzo. Il token non va nei log (gli URL sono
  già registrati senza query);
- limite: 20 inviti l'ora per merchant e 3 al giorno per email, con il
  componente esistente `Throttle` (riuso, nessuna modifica);
- elenco inviti del merchant: email, scadenza, stato (in attesa, accettato,
  scaduto, annullato).

Accettazione (`PosInvitationController`, utente autenticato):
- GET mostra merchant e richiesta di conferma; POST con CSRF accetta;
- condizioni, tutte verificate in transazione con il record invito `FOR UPDATE`:
  token valido, non scaduto, non annullato, non già usato; email dell'utente
  connesso uguale a quella invitata (confronto normalizzato); account attivo di
  livello base (D2); utente non già operatore di un merchant (PK `user_id`);
- esito: riga `pos_operators` **disabilitata** (default C1) e invito segnato
  come accettato. Il merchant poi abilita il profilo e concede i negozi;
- qualunque condizione fallita: stesso messaggio generico, invito non consumato.

Nuova tabella `pos_operator_invitations` (migration additiva, timestamp da
riservare al master): `id`, `merchant_id` (FK RESTRICT), `email`
VARCHAR(254), `token_hash` CHAR(64) UNIQUE, `created_by` (FK users),
`created_at`, `expires_at`, `accepted_at`, `accepted_user_id`, `revoked_at`
(BIGINT Unix come C1). Nessuna modifica alle tabelle C1.

**D2 - Solo utenti base.** Operatori solo account attivi di livello 0. Admin e
merchant esclusi; il titolare che usa la cassa usa un secondo account base.

**D3 - Disconnessione immediata.** Disabilitando il profilo, nella stessa
transazione si revocano tutte le sessioni POS attive dell'utente
(`PosApi::revoke`, motivo `operator_disabled`). Grant e terminali disabilitati
hanno effetto dalla richiesta API successiva (C2), senza revocare la sessione.

## 5. Regole di sicurezza delle scritture

- Accesso: `AccessControl` con `roles => ['@']` + `matchCallback` sul ruolo;
  poi controllo record-level su ogni identificativo.
- Metodi: `VerbFilter` con POST su tutte le scritture; CSRF attivo
  (`ActiveForm` / `Html::beginForm`), nessuna eccezione.
- Form dedicati in `models/forms/pos/*` con soli campi ammessi (nome, negozio
  cifrato, email e merchant cifrato per l'invito). `merchant_id`, `public_id`, `is_enabled`,
  timestamp e identità non arrivano mai dal client; i valori derivano dai record
  in scope. I tre AR C1 restano invariati e già bloccano le riassegnazioni.
- Servizio `components/pos/management/*`: ogni scrittura in transazione, con
  rilettura del record in scope `FOR UPDATE` prima di modificarlo; violazioni
  di unicità/FK (anche concorrenti) diventano un errore generico, mai il
  messaggio del DB.
- Audit (`Log::TYPE_DATA`): attore, azione, `public_id` del terminale o ID
  operatore/negozio, esito. Nomi con `Log::quote`. Mai email in chiaro,
  sessioni o token.
- Output: `Html::encode` su nomi di terminali, negozi, merchant e operatori.
- Errori: flash generici; dettagli solo nel log applicativo.

## 6. Test previsti (`tests/application/pos-management.php`, DB usa-e-getta)

Runner dedicato `tests/docker/pos-management.sh` sul modello di
`pos-catalog.sh`, stesso DB `napay_test_runtime` con conferma
`isolated-fixture`, fixture proprie senza modificare quelle comuni.

- Ruoli: admin, merchant proprietario, merchant altrui, merchant senza riga
  `merchants`, utente base, anonimo.
- Scope: elenchi e conteggi senza dati di altri merchant; filtri e pagine
  manipolati.
- ID alterati: UUID altrui, ID cifrati altrui o malformati, array: 404.
- POST manipolati: `merchant_id`/`public_id`/`is_enabled` aggiunti ignorati;
  negozio di altro merchant rifiutato; grant cross-merchant rifiutato.
- CSRF assente o errato: 400; GET sulle scritture: 405.
- Creazioni disabilitate per default; enable/disable con audit.
- Inviti: risposta identica con e senza account; token solo come digest;
  scaduto, annullato, riusato, di un altro utente o con email diversa:
  rifiutati senza consumarlo; due accettazioni concorrenti, una sola riesce;
  limiti di invio; nessun token nei log.
- D2: account non attivo, admin, merchant, già operatore: rifiutati.
- D3: disabilitazione profilo revoca le sessioni attive dell'utente e non
  quelle di altri.
- Nomi malevoli (`<script>`, `=formula`) codificati in tutte le viste.
- Concorrenza: due grant uguali in parallelo, uno solo riesce.
- Regressioni: suite C1, login/logout API.

## 7. Richieste e segnalazioni al master

- Voce di menu nella sidebar (admin e merchant): file condiviso, patch
  nell'handoff alla consegna.
- Eventuale riga nel runner comune: alternativa al runner dedicato.
- Sicurezza (fuori C4, file condivisi): la registrazione pubblica permette di
  scegliersi il ruolo merchant; `User::getMerchantId()` prende il primo merchant
  in modo arbitrario.
- Timestamp della migration `pos_operator_invitations` da riservare
  nell'ordine delle migration.

## 8. Fuori perimetro

Creazione di account da parte del merchant, delete, trasferimenti e
riassegnazioni, apertura/sblocco/disponibilità reale, API POS, modifiche ai
modelli C1, a `Users`/`Stores`/`Merchants`, routing, layout, runner comune,
BTCPay e import legacy.
