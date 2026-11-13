# B1-F Worker - Review master

2026-11-13. Piano W1-W5 approvato; sviluppo su worktree distinti dal servito.

## W1 - Persistenza

Approvato e integrato solo nel branch `feature/v2-btcpay-b1-integration`:
`00cf312c`, `ab11368e`, `634931b7`, `dbd42fab`. Runner master **53 PASS**,
worker DB limitato, gare due connessioni e bootstrap no-op.

Review risolte: RV1 password DB nella trace strutturata del costruttore,
RV2 promozione solo dopo stato verified e lettura generazione per ripresa,
RV3 revoca con CAS che non azzera busta su versione obsoleta.

W1 non effettua chiamate remote; il CAS del record non sostituisce il fencing
della lease del lavoro. W3 deve applicare guardia e mutazioni nella medesima
transazione. Nessun riuso di impostazioni o identificativi BTCPay legacy.

## W2 - Passi Remoti

Autorizzato al codice CLA, solo nuove classi steps e test. Riusa callable
del client HTTP gia approvato; nessun trasporto parallelo, DB, hook o daemon.
Tabelle B1-PROPOSTA 3.1/3.2 vincolanti: checkpoint persistiti a carico W3,
nessun secondo POST store/app dopo esito ignoto, marker unico esatto per
adozione, credenziali non verificate mai correnti.

Approvato: master **89 PASS**, integrato `bee8de2a`, `7fe6cabd`,
`2ac221e0`, `7fed6e85`. Review risolte: app solo PointOfSale e liste valide,
link sospesi mai completati per un vecchio ID, permessi chiave esatti,
429 sulla creazione chiave deferred (nessun retry automatico).

## W3a - Fencing Atomico

CLA autorizzato a estendere le API CAS della coda con mutazione opzionale
dei mapping nella transazione interna: owner/version/lease prima della
mutazione, tempo fresco sul CAS finale, rollback di job e mapping insieme.
Le transazioni esterne restano vietate, HTTP sempre fuori transazione.
Worker/console W3b dopo review del fencing; nessun deploy in questa fase.

Approvato e integrato `c586a4f0`, `89285cbf`: **18 PASS** master con worker
ristretto, due connessioni, crash e scadenza nel callback. Le mutazioni che
restituiscono CAS false/null devono essere controllate dal callback ed
alzare eccezione: la coda non puo dedurre il significato di un return void.

## W3b - Executor Account

CLA autorizzato al codice, prima solo merchant_account/runOnce. Account
serializzato anche tra generazioni diverse, checkpoint e mapping atomici,
HTTP fuori transazione, identita attiva verificata prima e dopo la rete.
qualifiedMerchant da solo non controlla is_active: usare anche riscontro
merchantForManager del gestore. Store/app, riconciliazione automatica e
daemon non sono inclusi in questo primo executor.
