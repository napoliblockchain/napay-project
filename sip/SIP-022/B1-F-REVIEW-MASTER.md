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
adozione, credenziali non verificate mai correnti. In attesa della consegna.
