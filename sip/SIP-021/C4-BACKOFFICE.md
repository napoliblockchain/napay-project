# C4 - Backoffice terminali, operatori e grant

- Autore: agente Napay. Aggiornato: 2026-11-12, regole definitive SIP-023.
- Riferimenti: [SIP-023](../SIP-023-profili-soci-merchant-operatori.md),
  [R1 policy](../SIP-023/R1-POLICY-CONDIVISA.md),
  [handoff R1](../SIP-023/HANDOFF-AGENTE-NAPAY.md),
  [approvazione C4](C4-APPROVAZIONE.md), SIP-021 sezione C1.
- Branch `feature/v2-napay-backoffice-c4`; base `a3fd15f3` + dipendenze
  master importate (R1, catalogo C2, R2 email, login D3: vedi handoff).
- Stato:
  - **parti A-C** (scope, terminali, profili esistenti, grant, revoca D3):
    implementate, correzioni RV1/RV2 e gare C4+API reali; in attesa di review;
  - **parte D** (inviti): implementata nel worktree e testata su DB usa-e-getta
    alle condizioni della sezione 5 ([handoff R2-D3](../SIP-023/HANDOFF-R2-D3.md));
    in attesa di review. Scostamento dallo schema proposto: niente colonna
    generata `active_key` (vedi tabella schema).

## 1. Regole di riferimento (SIP-023, decisioni dell'utente)

- Socio PF: solo associazione. Socio PG: può autoattivare il proprio merchant;
  lo stesso account ne diventa l'unico gestore e resta socio PG.
- Gestore: amministra un solo merchant; non usa il POS; crea solo operatori.
- Operatore: account dedicato, non socio, nato dall'invito; un solo merchant;
  negozi solo tramite grant espliciti. Socio che vuole lavorare in cassa: altro
  account, altra email.
- Admin: funzioni esplicitamente autorizzate; mai operatore per ruolo.
- Merchant diversi non condividono gestori né operatori. Mai `merchants[0]`.

## 2. Gate di identità: solo `AccountEligibility`

C4 non copia query di classificazione: chiama la policy condivisa.

| Uso in C4 | Metodo |
| --- | --- |
| Scope del gestore | `merchantForManager((int) Yii::$app->user->id)`; `null` = nessuno scope, 403 |
| Merchant su cui si può **concedere** (abilitare terminale, profilo, grant; creare grant o terminale) | `qualifiedMerchant($merchantId)` |
| Account a cui si può concedere (abilitare profilo, creare/abilitare grant) | `isOperatorAccount($userId)` |

- Admin: `User::isAdministrator()` resta il controllo di ruolo; la policy non
  conferisce ruoli. L'admin seleziona un merchant con ID cifrato, solo come
  selettore: il servizio risolve il record e ne ricava `merchant_id`.
- Riduzioni di privilegio (disabilitare terminale, profilo, grant) restano
  possibili anche su dati incoerenti: sono il percorso esplicito di riduzione
  richiesto da R1. Le concessioni invece richiedono identità coerente.
- Flag e grant C1 restano controlli separati: `isOperatorAccount` non li verifica.

## 3. Attori e scope

| Attore | Condizione | Lettura | Scrittura |
| --- | --- | --- | --- |
| Admin | `isAdministrator()` | tutti i merchant | concessioni solo su merchant qualificati; riduzioni ovunque |
| Gestore | `isMerchant()` e `merchantForManager` non nullo | solo il proprio merchant | come admin, solo sul proprio merchant |
| Tutti gli altri | - | 403 | 403 |

- Scope applicato nella query prima di conteggi, ordinamento e paginazione.
- Record fuori scope o inesistente: 404, senza distinguere i due casi.
- Il gestore non riceve mai grant né profilo operatore per ruolo.

## 4. Parti A-C: funzioni (autorizzate)

Controller `PosManagementController` (`/pos-management/...`), servizio in
`components/pos/management/`, form in `models/forms/pos/`.

| Action | Metodo | Effetto | Gate di concessione |
| --- | --- | --- | --- |
| `index` | GET | terminali e operatori in scope, filtro negozio, pager unico | - |
| `terminal-create` | GET/POST | nome + negozio in scope; nasce disabilitato | `qualifiedMerchant` |
| `terminal-update` | GET/POST | solo nome | - |
| `terminal-enable` | POST | abilita | `qualifiedMerchant` |
| `terminal-disable` | POST | disabilita | - |
| `operator-view` | GET | profilo e grant per negozio | - |
| `operator-enable` | POST | abilita profilo esistente | `qualifiedMerchant` + `isOperatorAccount` |
| `operator-disable` | POST | disabilita e revoca subito le sessioni POS (D3) | - |
| `grant-create` | POST | grant verso un negozio del merchant dell'operatore; nasce disabilitato | `qualifiedMerchant` + `isOperatorAccount` |
| `grant-enable` | POST | abilita | `qualifiedMerchant` + `isOperatorAccount` |
| `grant-disable` | POST | disabilita | - |

- Disponibilità terminali sempre "Non verificata"; nessun comando di apertura,
  chiusura o sblocco. Niente delete, trasferimenti o riassegnazioni.
- Identificativi: terminale = `public_id`; operatore e negozio = ID cifrati
  con `Crypt`, decodifica tollerante; malformati, array o lunghi: 404.
- Profili operatore oggi esistono solo da fixture o futuri inviti: C4-A..C non
  crea profili.

### Scritture

- `VerbFilter` POST e CSRF su tutte; form con soli campi ammessi; nessun mass
  assignment sugli AR C1 (che già bloccano riassegnazioni).
- Transazione `READ COMMITTED` (solo quella transazione), nell'ordine dei
  lock comune al login POS (`PosApi::createSession`):
  1. `FOR UPDATE` della riga `merchants`, poi scope dell'attore ricalcolato
     (`merchantForManager` per il gestore) su dati correnti;
  2. `FOR UPDATE` del profilo operatore (azioni su operatori e grant);
  3. `FOR UPDATE` dell'utente, solo per le concessioni, poi gate R1;
  4. `FOR UPDATE` di negozio, grant o terminale, con verifica del merchant;
  5. sessioni (`FOR UPDATE`) per la revoca D3;
  6. scrittura, audit, commit.
  Gli ID letti prima dei lock sono indizi; un modello letto prima non viene
  riusato.
- D3: `operator-disable` revoca nella stessa transazione tutte le sessioni POS
  attive dell'utente (`PosApi::revoke`, motivo `operator_disabled`). La
  riabilitazione non le riattiva: serve un nuovo login. Il login Napay
  dell'account non viene toccato.
- Errori: messaggio generico; nel log solo classe dell'eccezione, mai query,
  POST, sessione o credenziali. Audit `Log::TYPE_DATA` con attore, azione,
  `public_id`/ID, esito; nomi con `Log::quote`.

## 5. Parte D: inviti operatore (disegno approvato, implementazione condizionata)

### Condizioni del master (HANDOFF-R2-D3, vincolanti)

- Email: `EmailIdentity::normalize` e `condition` (R2) e indice UNIQUE
  `uq-users-email-normalized` come autorità. Violazione UNIQUE concorrente =
  rollback completo, invito non consumato, nessun account duplicato, errore
  generico. Mai query `WHERE email=...` con la collation della tabella.
- Accettazione: token cercato solo come indizio; **lock del merchant prima del
  lock dell'invito**; poi riletti sotto lock digest del token, merchant, stato
  e scadenza. Emissione, reinvio e annullamento seguono lo stesso ordine
  (merchant -> invito), mai l'inverso.
- Account creato: base, attivo, `is_merchant = 0`, nessun profilo socio né
  quote; profilo operatore esplicito **disabilitato**, nessun grant. Mai
  `SignupForm::signup`, ruolo scelto dal POST, logica primo-admin, reset o
  riuso di account esistenti.
- Mail su file nei test; token solo come digest nel DB; nessun token o
  password in log o risposte al merchant. Limiti di invio anche sugli avvisi
  a indirizzi già registrati.
- Solo worktree e DB usa-e-getta: nessun DDL sulla sandbox condivisa, nessun
  operatore reale. Accesso al portale e registrazione PF/PG restano R3 del
  master: la consegna inviti non chiude SIP-023.

### Flusso

1. **Invito.** Gestore (o admin su un merchant qualificato) inserisce un'email.
   - Normalizzazione come la policy: `LOWER(TRIM(email))`; validazione email,
     massimo 60 caratteri (limite di `Users.email`).
   - Al merchant sempre la stessa risposta ("invito registrato"), qualunque sia
     lo stato dell'indirizzo: nessuna enumerazione.
   - Se l'email appartiene già a un account (socio, gestore, operatore, altro):
     all'indirizzo arriva un avviso "questo indirizzo ha già un account Napay:
     per lavorare in cassa serve un'altra email", senza link di accettazione.
     Nessun collegamento, nessun cambio password.
   - Altrimenti email con link `/pos-invitation/accept?token=...`.
2. **Apertura del link (GET).** Mostra merchant, email (sola lettura) e form:
   nome, cognome, password, conferma. Non consuma il token. Con un utente già
   connesso a Napay: chiede di uscire prima, non collega l'account attuale.
3. **Accettazione (POST con CSRF).** In una transazione:
   1. lock `FOR UPDATE` della riga `merchants` (da indizio del token):
      ancora `qualifiedMerchant`;
   2. lock `FOR UPDATE` dell'invito, riletto per digest e merchant: attivo,
      non scaduto, non consumato;
   3. nessun account con quell'email normalizzata (`EmailIdentity`);
   4. l'indice UNIQUE resta l'autorità contro le gare;
   5. creazione account: livello base, attivo, `username` = `email`, password
      con `Yii::$app->security->generatePasswordHash`, `authKey`/`accessToken`
      casuali; nessun `is_merchant`, nessun socio, quote o ruoli associativi;
   6. riga `pos_operators` **disabilitata** per quel merchant;
   7. invito consumato (data e account creato), audit, commit.
   Qualunque condizione fallita: messaggio generico, nessuna scrittura, invito
   non consumato. Il gestore poi abilita il profilo e concede i negozi (parte C).

### Token, scadenza, reinvio

- Token: 32 byte casuali in base64url; nel DB solo SHA-256; mai mostrato al
  merchant, mai nei log (gli URL sono registrati senza query).
- Scadenza 72 ore. Monouso: consumo atomico al punto 3.
- Un nuovo invito per la stessa coppia merchant/email annulla quello attivo.
- Email non inviata: invito resta attivo con stato "invio non riuscito".
  **Reinvia** genera un nuovo token (il vecchio smette di valere) e una nuova
  scadenza. **Annulla** revoca l'invito attivo.
- Limiti (componente `Throttle`, riuso): 20 inviti/ora per merchant,
  3/giorno per email normalizzata, 10 accettazioni/minuto per IP.
- Elenco inviti del merchant: email digitata, stato (in attesa, invio non
  riuscito, accettato, scaduto, annullato), scadenza.

### Concorrenza ed email

- Inviti di merchant diversi alla stessa email: ammessi; la prima accettazione
  crea l'account, le altre falliscono (account già presente o violazione
  UNIQUE) senza consumare l'invito.
- Accettazione contro registrazione pubblica: decide l'indice UNIQUE R2;
  chi perde ottiene un errore generico, nessuna scrittura parziale.

### Schema `pos_operator_invitations` (timestamp riservato `m261112_140000`)

Additiva, nessuna modifica alle tabelle C1; convenzioni C1 (InnoDB, utf8mb4,
`utf8mb4_0900_bin`, BIGINT Unix, FK RESTRICT).

| Colonna | Tipo | Note |
| --- | --- | --- |
| `id` | INT AUTO_INCREMENT | PK |
| `merchant_id` | INT | FK `merchants.id` |
| `email` | VARCHAR(60) | normalizzata, CHECK non vuota |
| `token_sha256` | CHAR(64) ascii | UNIQUE |
| `created_by` | INT | FK `users.id` (gestore o admin) |
| `created_at`, `updated_at`, `expires_at` | BIGINT | |
| `sent_at` | BIGINT NULL | ultimo invio riuscito |
| `send_failures` | SMALLINT | contatore |
| `consumed_at` | BIGINT NULL | |
| `consumed_user_id` | INT NULL | FK `users.id` |
| `revoked_at` | BIGINT NULL | annullato o sostituito |

Implementato senza la colonna generata `active_key` proposta: un solo invito
attivo per merchant/email è garantito dal lock della riga `merchants`, preso
per primo da emissione, reinvio, annullamento e accettazione (stesso ordine
merchant -> invito). `email` è VARCHAR(255) come `users.email` (limite
applicativo 60). CHECK: email 3-255 caratteri, token 64, tempi coerenti,
`send_failures >= 0`, consumo e utente consumatore entrambi nulli o valorizzati,
mai consumato e annullato insieme.

Indici: `(merchant_id, created_at)` per l'elenco. Rollback distruttivo
disabilitato come nelle migration C1.

### Test previsti (parte D)

Risposta identica con email libera, socio, gestore o operatore; nessun
collegamento o cambio password di account esistenti; token solo come digest;
link scaduto, annullato, sostituito o già usato rifiutato senza scritture;
due accettazioni concorrenti e accettazione contro registrazione pubblica: un
solo account; varianti maiuscole/spazi trattate come la stessa email; utente
connesso non collegato; nessun socio/quote creati; profilo creato disabilitato
e senza grant; invio fallito e reinvio; limiti; nessun token nei log o nelle
risposte al merchant (mail su file).

## 6. Test parti A-C (`tests/application/pos-management.php`)

Runner dedicato `tests/docker/pos-management.sh` (confermato), su DB
usa-e-getta, fixture proprie: PG socia con ragione sociale e gestore di livello
merchant, secondo merchant qualificato, merchant non qualificato, operatori
coerenti e incoerenti (socio + operatore).

- Ruoli: admin, gestore, gestore di altro merchant, merchant non qualificato,
  socio, operatore, anonimo.
- Scope su elenchi, conteggi e pagine; ID e UUID altrui o malformati: 404.
- POST manipolati (campi extra ignorati, negozio altrui rifiutato); CSRF
  assente: 400; GET su scritture: 405.
- Concessioni rifiutate su merchant non qualificato e operatore incoerente;
  riduzioni sempre possibili.
- D3: sessioni dell'operatore revocate, quelle di altri intatte; riabilitazione
  senza riattivazione.
- Nomi malevoli codificati; nessun dato sensibile nel registro.
- Regressioni: policy R1, C1, login/logout API.

## 7. Richieste al master

- Review delle parti A-C corrette (RV1/RV2, gare C4+API).
- Sidebar: voce "Terminali POS" (patch alla consegna).
- Da R0/SIP-023, fuori C4: operatori che entrano nel backoffice Napay non
  devono vedere funzioni da socio; registrazione pubblica con `is_merchant`.

## 8. Fuori perimetro

Registrazione PF/PG e autoattivazione merchant (master), delete,
trasferimenti, riassegnazioni, apertura/sblocco/disponibilità reale, API POS,
modifiche a modelli C1, `Users`, `SignupForm`, `AccountEligibility`, routing,
layout, runner comuni, BTCPay, import legacy.
