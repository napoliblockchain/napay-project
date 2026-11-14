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

Review W3b iniziale:30 test master verdi, ma RV1 trace di dipendenze/callback,
RV2 GET key_saved senza guardia iniziale, RV3 ensureAccount fuori fencing,
RV4 entity_id non verificato restano aperti. Correzioni passate al master
alle19:15 dopo assenza di presa in carico; worktree CLA conservato intatto.

2026-11-14: RV1..4 chiuse dal master e integrate nel solo branch isolato:
`9c0cb8d1` codice, `5fdfcd9f` test (base CLA `d096282f`/`81498b5f`).
**37 PASS** worker, **63** coda, **18** fencing; review indipendente senza
nuovi finding. Preparazione CAS running prima di ensureAccount e snapshot
GET, controllo entity_id=merchant_id, tenant fresco anche sui retry,
parametri sensibili e boundary senza trace native/previous. Coperti mapping
assenti su merchant inesistente/disabilitato, lease scaduta anche tra prima
preparazione e GET, disabilitazione durante429, HTTP sempre fuori transazione.
CLI dedicata collegata come documentato in B1-G. Nessun deploy o pagamento.

## W4a - Outbox Negozi E Terminali

CLA autorizzato su file distinti: ProvisioningOutbox e hook StoresController/
PosManagement. Web riceve solo digest pubblico BTCPAY_PROVISION_INSTANCE
(SHA256 dell'origine worker); vuoto mantiene feature non attiva, valore
non vuoto malformato blocca la transazione. Nessuna chiave o HTTP nel web.
Inserimento job generation1 idempotente nella stessa transazione della
nuova risorsa, scope merchant/negozio/terminale verificato. Solo colonne
WEB_ENQUEUE, nessun UPDATE o INSERT IGNORE che nasconda errori diversi da
duplicato1062. Hook attivazione merchant assegnato a CLA il2026-11-14 per
parallelizzare senza toccare Worker/Jobs/CLI del master.
Test con utente web ristretto, rollback congiunto, replay e feature disattiva.

Review W4a: master34 test verdi con overlay reale, richiesti fix Connection
SensitiveParameter e current read del replay sotto REPEATABLE READ, con
controprove dedicate. W4b include enqueueMerchant nella medesima transazione
di creazione merchant/promozione PG, rollback congiunto; nessuna modifica
alle policy identita, schema, GRANT o chiavi.

2026-11-14: W4a approvato, **44 PASS** master e **32** bootstrap ruoli;
test integrati e runtime completa verdi. W4b approvato dopo rimozione del
backfill implicito: **33 PASS** master anche sul branch integrato.
Commit W4b `af0e095f`, `93379868`, `42e81adc`, `48b8c46c`, `09876b57`.
Attivazione avvenuta a feature spenta + replay dopo enable NON accoda;
un eventuale recupero dei merchant esistenti richiede azione esplicita.
Nessun rollout, modifica privilegi o onboarding BTCPay reale.

## Prossimi Executor

Contratto [W3c link](B1-H-LINK-WORKER.md) assegnato a CLA su nuovi file;
master mantiene Jobs/CLI e [W3d GET-only](B1-I-RECONCILIATION-QUEUE.md).
Worktree separati, nessuna modifica al checkout servito. Riconciliazione
automatica e routing CLI link non sono ancora collegati.
