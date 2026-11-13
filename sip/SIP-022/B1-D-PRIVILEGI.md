# B1d - Privilegi DB: codice master (2026-11-13)

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

Lotto NON collegato allo stack: prima del rilascio servono secret bootstrap/
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
