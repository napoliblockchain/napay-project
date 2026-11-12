# C4 - Backoffice terminali, operatori e grant (BOZZA, da approvare)

- Autore: agente Napay. Data: 2026-11-12.
- Riferimenti: SIP-021 (sezioni C1 e scomposizione), [handoff C1](C1-HANDOFF.md),
  [prompt](PROMPT-AGENTE-NAPAY.md), `napay/tests/application/POS-CATALOG.md`.
- Base: Napay `a3fd15f3`, branch `feature/v2-napay-backoffice-c4`.
- Stato: solo documento. Nessun codice finché il master non approva questo
  allegato e l'utente non chiude le decisioni D1-D3.

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

Controller unico `PosManagementController` (`/pos-management/...`).

| Action | Metodo | Admin | Merchant | Effetto |
| --- | --- | --- | --- | --- |
| `index` | GET | sì | sì | due schede: terminali e operatori, filtro per negozio |
| `terminal-create` | GET/POST | sì | sì | nome + negozio (solo negozi in scope); `merchant_id` dal negozio; nasce disabilitato |
| `terminal-update` | GET/POST | sì | sì | solo nome |
| `terminal-enable` / `terminal-disable` | POST | sì | sì | flag `is_enabled` |
| `operator-link` | GET/POST | sì | **D1** | collega un account a un merchant; nasce disabilitato |
| `operator-view` | GET | sì | sì | profilo + grant per negozio |
| `operator-enable` / `operator-disable` | POST | sì | sì | flag profilo; disable revoca le sessioni POS (**D3**) |
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

## 4. Collegamento degli account operatore (decisioni richieste)

**D1 - Chi collega un account esistente a un merchant come operatore.**
Il merchant non può avere un elenco globale utenti né rivendicare un account
indicando ID o email (chiunque conosca un'email potrebbe legarla al proprio
merchant, e la PK `pos_operators.user_id` impedirebbe poi al vero merchant di
usarla).

| Opzione | Come | Prova di assegnabilità | Costo |
| --- | --- | --- | --- |
| **A (consigliata per il 23/11)** | Solo l'admin collega: email esatta dell'account + merchant | verifica fuori banda dell'admin (come per la creazione dei merchant) | nessuna tabella nuova, nessun flusso email |
| B | Il merchant invita un'email; l'utente accetta dal proprio account con link firmato | consenso dell'intestatario dell'account | nuova tabella inviti (migration da riservare), email, scadenza/revoca |
| C | Il merchant crea l'account operatore | l'account nasce già suo | tocca `Users`/registrazione (file condivisi) |

Con A il merchant gestisce in autonomia terminali, grant e abilitazioni dei
propri operatori, ma non collega nuovi account: lo chiede all'admin.
B è il passo successivo naturale se servirà autonomia.

**D2 - Quali account possono diventare operatori.**
Proposta: solo account attivi (`is_active = 1`) di livello base (0), come
indicato in SIP-021 punto 2. Esclusi admin e merchant: un titolare che vuole
usare il POS usa un secondo account base. Account già operatore di un merchant:
rifiutato con messaggio generico (PK `user_id`).

**D3 - Effetto della disabilitazione del profilo operatore.**
Proposta: nella stessa transazione revocare tutte le sessioni POS attive
dell'utente (`PosApi::revoke`, motivo `operator_disabled`). Grant e terminali
disabilitati invece hanno effetto dalla richiesta API successiva (C2), senza
revocare la sessione. Alternativa: nessuna revoca, solo controllo in C2.

## 5. Regole di sicurezza delle scritture

- Accesso: `AccessControl` con `roles => ['@']` + `matchCallback` sul ruolo;
  poi controllo record-level su ogni identificativo.
- Metodi: `VerbFilter` con POST su tutte le scritture; CSRF attivo
  (`ActiveForm` / `Html::beginForm`), nessuna eccezione.
- Form dedicati in `models/forms/pos/*` con soli campi ammessi (nome, negozio
  cifrato, email/merchant per D1). `merchant_id`, `public_id`, `is_enabled`,
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
- D1/D2: account non attivo, admin, merchant, già operatore: rifiutati.
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
- Decisioni D1-D3 da far confermare all'utente.

## 8. Fuori perimetro

Creazione o invito di account (salvo D1-B approvata), delete, trasferimenti e
riassegnazioni, apertura/sblocco/disponibilità reale, API POS, modifiche ai
modelli C1, a `Users`/`Stores`/`Merchants`, routing, layout, runner comune,
BTCPay e import legacy.
