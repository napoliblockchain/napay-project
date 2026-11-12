# SIP-023 R2 - Email univoca e prerequisito inviti

Master, 2026-11-12. Decisione: UNIQUE DB definitivo, non lock applicativo ponte.

## Contratto prima del codice

- Migration additiva riservata al master:
  `m261112_135000_unique_normalized_user_email.php`, dopo C1 e prima inviti140000.
- `users.email` resta invariata: VARCHAR(255) fisica, limite applicativo 60.
  Nessun aggiornamento massivo email/username, merge, cancellazione o cambio ruolo.
- Colonna `email_normalized` VARCHAR(255), utf8mb4/utf8mb4_0900_bin,
  STORED GENERATED ALWAYS AS (LOWER(TRIM(email) COLLATE utf8mb4_0900_bin)). UNIQUE
  `uq-users-email-normalized`, CHECK `ck-users-email-normalized-present` non vuota.
- Preflight soli conteggi: email nulla/vuota e collisioni della medesima
  espressione/collation dell'indice. Anomalie = errore fisso, prima del DDL;
  nessuna email/query nel log. Riconciliazione legacy richiede decisione esplicita.
- MySQL 8.4/InnoDB; colonna origine VARCHAR(255) UTF8MB4 non nullable.
  Oggetti omonimi preesistenti accettati solo se equivalenti esatti (espressione,
  tipo, collation, generazione stored, indice completo unico visibile, CHECK
  enforced). DDL mancante in un unico ALTER atomico, niente rollback distruttivo.
- Normalizzazione applicativa ASCII lowercase + spazi ai bordi; email non ASCII
  non introdotte dai form (validator email esistente). Query identita/policy
  devono usare stessa espressione con collation binaria, non quella accent-
  insensitive ereditata dalla tabella. Per Unicode legacy entrambi gli operandi
  sono normalizzati da MySQL, con collation 0900_bin applicata PRIMA di LOWER:
  nessuna dipendenza dalla versione Unicode PHP o dalla collation legacy/di
  connessione. Applicarla soltanto dopo LOWER non basta (caso U+1E9E).
  Nessun provider-specific aliasing.
- Users/SignupForm: validazione unicita preventiva per UX; indice DB resta
  autorita contro gare. Registrazione gestisce collisione IntegrityException
  con errore campo generico e nessun dump di validator/SQL. Non riusa account.
- Per questo micro-step non si cambia scelta profilo/merchant nel signup:
  adeguamento PF/PG e autoattivazione restano R3, non dichiarati gia conclusi.

## Verifiche

Dataset v2 ripristinato soltanto su DB usa-e-getta, conteggi senza PII.
Test: preflight duplicati/vuoti prima DDL, schema omonimo incompatibile, resume
esatto, indici e CHECK effettivi, due inserimenti concorrenti su stessa email,
maiuscole/spazi, lookup e signup, fallimenti senza dettagli sensibili.
Le vecchie suite che simulano duplicati possono rimuovere temporaneamente
l'indice solo nel DB usa-e-getta, ripristinandolo dopo pulizia in finally.
Nessun comando migration sulla sandbox condivisa in questo micro-step.

## Confini paralleli

Master: modelli, signup, policy, migration e test R2; niente edit C4.
Agente C4: continua correzioni A-C, D resta bloccata fino a consegna R2 testata.

## Consegna verificata

Napay `121fe3a2`: migration, helper `EmailIdentity`, lookup/policy, signup e
recupero account allineati. Audit su restore v2 + fixture: 10 account,
0 email vuote, 0 gruppi duplicati, 0 oltre 60 caratteri (solo conteggi).
Nessuna riscrittura dei dati sorgente e nessuna migration nella sandbox condivisa.

Eseguiti dal master sul codice finale: 106 controlli schema/SQL (incluse due
connessioni, race prima DDL, INSERT/UPDATE e Unicode), 14 applicativi email,
68 reset password, 92 attivazione, 24 policy; bootstrap gia completo/no-op.
Sintassi PHP 8.3.36 Docker e shell verificate, diff controllato. Nessun PHPStan
configurato nel repository. I test di schema/corruzione operano solo nel DB usa-e-getta.

Per D: riusare `EmailIdentity::normalize` e `condition`, mantenere indice/check
intatti e gestire anche la collisione DB, non soltanto il precontrollo.
Non copiare vecchie query `WHERE email=...` con collation ereditata.
La creazione soci PF/PG e l'autoattivazione merchant non sono implementate da R2.
