# B1d - Privilegi DB: codice master (2026-11-13)

Stato attuale: codice e overlay verificati sul branch isolato
`feature/v2-btcpay-b1-integration`; launcher e sandbox non ancora attivati.

Primo lotto: componente DatabaseRoles applica a tre account DB dedicati
esistenti la matrice B1b: migrator proprietario schema, web CRUD per tabella
applicativa ma solo lettura storia/bootstrap e stati B1, outbox INSERT a
colonne ammesse; worker B1 SELECT/INSERT/UPDATE, colonne Napay minime e log
INSERT. Credenziali B1 sempre invisibili al web. Nessun GRANT OPTION.

Preflight completo prima dei REVOKE; account distinti e dedicati, MySQL8.4,
schema corrente e tabelle richieste; rifiutare privilegi preesistenti fuori
schema anziche cancellarli. Grant non transazionali: fallimento parziale
nega accesso e richiede riesecuzione, mai fallback a privilegi piu ampi.
Test con tre utenti temporanei e DB usa-e-getta, incluso vecchio grant
schema-wide da restringere. Nessuna password gestita dal componente.

Il lotto iniziale non era collegato allo stack: prima del rilascio servivano secret bootstrap/
worker non visibili al web, migrazioni con migrator e readiness web limitata
al marker bootstrap di sola lettura (verifica schema completa al migrator).
Nessuna modifica o revoca nella sandbox condivisa durante questo step.

## Esito Primo Lotto

Codice master `afa6e702` nel branch isolato: DatabaseRoles e runner dedicato.
**59 PASS** con tre account reali usa-e-getta: restrizione grant storico,
colonne outbox, credenziali vietate al web anche COUNT/SHOW CREATE, worker
minimo, DDL solo migrator, preflight senza revoche su errori, account bloccato,
colonna mancante, schema underscore senza wildcard, replay idempotente.
Root secret montato esclusivamente nel bootstrap di test; no-op finale verde.
Lint PHP8.3.36/shell e diff verificati. Nessuna modifica DB/sandbox condivisa.
Collegamento bootstrap/compose/secret/readiness ancora da implementare.

Review CLA: DR1 readiness web e DR2 readiness worker confermano i blocchi
noti prima del collegamento allo stack. Nessun rilascio autorizzato finche
risolti. DR3 verificata con il vero Log::save/Yii sul PDO worker: scrittura
riuscita e riga verificata; suite ora **61 PASS**, commit test nel branch
integrato. Nessun SELECT su logs aggiunto al worker per far passare il test.

## Collegamento Bootstrap - Contratto Implementativo

Overlay dedicato `docker-compose.roles.yml`, nessun deploy sandbox in questo
step. Root e password migrator solo nel bootstrap, password worker solo in
bootstrap/worker-db-check; web conserva esclusivamente propria password.
Secret esterni 0600, directory private, lettura con controllo file/permessi.
Bootstrap crea solo account dedicati mancanti (nessuna rotazione implicita),
verifica credenziali, restringe web/worker prima delle DDL, migra col migrator,
poi applica matrice completa. Nessun fallback al root per migrazioni fallite.
Ripetere bootstrap con writer fermi: GRANT non transazionali, possibili errori
transitori se altri servizi interrogano il DB durante la riconfigurazione.

Readiness ristretta verifica marker complete/hash codice/storia migration e
privilegi propri senza DDL, GRANT OPTION o scritture sul marker; web mai sulle
credenziali. Verifica hash schema completo resta al bootstrap/migrator prima
di sbloccare servizi. Worker legge soltanto colonne marker e migration.version.
`worker-db-check` e una verifica one-shot, non il daemon di provisioning.
Test: avvio reale overlay, credenziali sbagliate, secret mancanti/permissivi,
readiness con utenti reali ristretti, bootstrap ripetuto senza reimport, HTTP
con ruoli applicati e credenziali privilegiate assenti dal web.

## Collegamento Implementato E Verificato

Commit codice `048dfa84`, overlay `6b5c76ed`, test `8da53cb0`, fixture private
read-only `96ebd679`, protezione trace `5ce940ec`. Overlay reale avviato su DB
usa-e-getta: **29** controlli bootstrap/readiness e regressione runtime
completa verdi; policy PDO unbuffered **61 PASS**. Coperti secret mancanti,
corti, leggibili da altri e password errata di account esistente: bootstrap
respinto senza rotazione implicita, web ancora ready. Log console privi di
tutte le password e successo stampato solo a completamento dell'intero job.

I tre fixture che rimuovono l'indice email storico sono eseguiti dal migrator
in un container dedicato, condividendo solo rete/runtime con il web. Nessun
privilegio DDL o secret migrator concesso al web, nessuna regressione saltata.
Reimport non eseguito sul secondo avvio; DB preservato dopo restart del web.
Anche runtime della modalita precedente eseguita verde.

DR1 e DR2 risolti nell'overlay; worker-db-check resta one-shot, non un daemon.
Restano launcher con controlli dei percorsi host, rollout con writer fermi e
backup, nuova migration/grant del backend POS prima della prova locale.
Nessuna migration, password, configurazione privata o riavvio nella sandbox
condivisa; readiness del Napay servito verificata ancora positiva.
Modifiche utente `4df5b5e8` preservate nel branch come `b7af8cf0`.

Residuo preesistente da verificare prima del P3 completo: le vecchie pagine
negozio usano ancora `settings.btcpayApiKey`/host e `storesettings.bps_storeid`.
La separazione implementata riguarda i nuovi secret DB e le credenziali B1;
non certifica la bonifica di eventuali credenziali legacy nel DB importato.
Il worker P3 non deve riusarle automaticamente: inventario senza valori in
output e riconciliazione esplicita restano nel piano di rollout/provisioning.

## Integrazione Negozi E Aperture POS

Consegne CLA approvate integrate nel branch isolato. `pos_terminal_openings`
richiede solo SELECT/INSERT/UPDATE al web, nessun DELETE (storico audit),
nessun privilegio al worker BTCPay. Suite separate su dati freschi per
runtime generale, negozi e aperture: nessuna regressione esclusa. Tutte
usano il medesimo overlay ruoli; POS e negozi non richiedono BTCPay attivo.

## Launcher Completato Nel Branch Isolato

Commit Napay `e1f8cb5d`, `35bcb7a3`: up richiede env privato esterno e
include sempre overlay ruoli. Preflight verifica modello Compose completo
(profilo db-check incluso nella sola ispezione), account/secret distinti,
percorsi canonici senza symlink, proprietario e permessi di env/secret/dataset.
Nessun servizio o volume creato prima della validazione; nessun fallback legacy.

`local.sh prepare-roles` prepara una sandbox esistente senza avviarla:
verifica in sola lettura l'assenza dei due account dedicati, poi genera
solo i due nuovi secret e aggiunge i riferimenti all'env. Account esistenti
senza originali, configurazione parziale o file mancanti bloccano ogni
rigenerazione. Prima installazione automatica, esclusioni Git locali prima
delle scritture; password root/login esistenti sempre preservate.

Test master: preflight26 e locale20 con Compose/PHP reali e operazioni
persistenti intercettate; suite MySQL reale verde, compresi account gia
presenti e backup/restore. Runtime completa con ruoli ristretti verde,
bootstrap/readiness32; POS61 e negozi21 su fixture fresche; schema B1 148.
Lint shell/PHP e diff verificati. Tutto su dati usa-e-getta.

Nessun rollout condiviso ancora eseguito. Restano backup aggiornato alla manutenzione,
preflight della sua configurazione, integrazione con writer fermi, avvio
tramite orchestratore e verifiche HTTP/TLS sullo stack locale. Il worker
di provisioning W1-W5 segue il piano B1-F; non e attivato da questo launcher.

Follow-up `528413a2`: password web validata dal modello Compose effettivo,
non dal testo grezzo dell'env. Coperti interpolazione debole, riuso root/web
e password interpolata valida. Preflight della configurazione locale reale
superato su copia privata temporanea; originali e servizi invariati.

E2E POS `872055f` (`feature/v2-pos-e2e-db-roles`):25 casi HTTP/TLS verdi sia
legacy sia restricted. In restricted si applica davvero overlay B1, con
readiness web/worker e controprove DDL, DELETE storico aperture e lettura
credenziali BTCPay negate al web. Nessun deploy o pagamento.

Fail-fast orchestratore: quando il checkout Napay contiene l'overlay ruoli,
`start-localhost.sh` ne esegue il preflight prima di avviare altri servizi.
Prima installazione normale: `local.sh init` prepara solo input privati,
poi check; `--check` senza env non genera credenziali. Configurazione legacy
richiede preparazione esplicita dei ruoli. Compatibilita col vecchio codice
servito mantenuta finche l'overlay non viene integrato. Test dedicato
`tests/localhost-preflight.sh`: **7 PASS**, Docker interamente intercettato.

## Backup Preliminare Del DB Servito

2026-11-13: backup logico privato in
`/var/www/blockchain-napoli/napay-local-data/backup-before-roles-20261113-tIgFffrj/`,
directory0700, file0600, fuori Git. Snapshot e checksum conservati; prova
di restore in MySQL usa-e-getta, stessa immagine del server sorgente,
rete disabilitata e nessuna porta host, risorse rimosse alla fine.

Primo confronto testuale segnalava34 colonne con esplicitazione ridondante
di CHARACTER SET utf8mb4 accanto a COLLATE utf8mb4_* (nessuna differenza di
INSERT). Confronto completo passato escludendo commenti e solo quel prefisso
DDL ridondante: valori, collation, default e resto dello schema invariati.
Nessuna normalizzazione di stringhe/dati o riscrittura del backup originale.
Checksum verificato e readiness del Napay servito ancora positiva.
Backup preliminare, non sostituisce snapshot fresco prima del rollout.
