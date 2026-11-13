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
