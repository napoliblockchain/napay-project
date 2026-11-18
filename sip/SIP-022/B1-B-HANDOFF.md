# SIP-022 B1b - Handoff codice schema (agente Napay, 2026-11-13)

- Via libera: `sip/SIP-022/B1-B-APPROVAZIONE.md` (orchestratore, `720be82`);
  schema: [B1-B-SCHEMA](B1-B-SCHEMA.md).
- Worktree `napay-worktrees/napay-btcpay-b1b`, branch
  `feature/v2-btcpay-b1b-schema`, base `c0a55ecb`. Commit: `ff7d1c73` (migration + verificatore C1),
  `36ce8fcc` (test).
- Nessun push/merge, nessuna sandbox, segreto reale, bootstrap, stack o worker.

## File

| File | Contenuto |
| --- | --- |
| `migrations/m261113_120000_create_btcpay_provisioning_schema.php` | 5 tabelle + `uq-btcpay-terminals-scope` (`id`, `store_id`, `merchant_id`) su `pos_terminals`; preflight completo prima di ogni DDL, ripresa solo su definizione identica, `down()` rifiutato |
| `migrations/m261112_130000_create_pos_catalog.php` | verificatore C1: ammesso solo quell'indice con definizione esatta |
| `tests/application/pos-catalog-schema.php` | indice B1 isolato con rinomina (mai `foreign_key_checks=0`), 3 derive rifiutate; `commandClass` deprecato -> `commandMap` |
| `tests/application/btcpay-provisioning-schema.php`, `tests/docker/btcpay-provisioning-schema.sh` | schema, vincoli, GRANT con utenti usa-e-getta |

## Scelte rispetto allo schema

- Nonce e DEK cifrata `VARBINARY(24/48)` + CHECK di lunghezza esatta;
  ciphertext 17..16400.
- Email tecnica: CHECK `technical_email = CONCAT('m-', ref, '@btcpay-merchants.jamprojects.it')`.
- CHECK della busta scritti con `IS [NOT] NULL` espliciti: un CHECK con esito
  NULL passerebbe. Impronta obbligatoria per `api_key` non revocate e vietata
  altrimenti.
- `in_flight_op`: `create_user`, `create_api_key`, `create_store`,
  `create_pos_app`, `revoke_api_key`.
- Verifica dei CHECK e della colonna generata: resa di MySQL 8.4.13 (vedi
  RV1 sotto). Dopo un `ALTER` qualunque MySQL riscrive `_utf8mb4'x'` in
  `_ascii'x'` sulle colonne ascii (verificato): introducer ammessi solo
  `_utf8mb4`/`_ascii`, fuori dai letterali.
- `stores`: basta un UNIQUE equivalente a (`id`, `merchant_id`) con qualunque
  nome, come ammette C1.
- Nessuna FK `jobs.merchant_id` (non prevista dallo schema approvato).

## Test (DB e utenti usa-e-getta)

- `tests/docker/btcpay-provisioning-schema.sh`: C1 **55 PASS** (4 nuovi),
  B1b **144 PASS**, bootstrap no-op dopo le prove. Coperti:
  - nessun backfill; replay identico; 8 derive rifiutate (colonna extra,
    `BINARY` al posto di `VARBINARY`, colonna generata, CHECK non applicato,
    dominio email, regex KEK, FK mancante, indice extra); nome indice
    terminali con altro ordine rifiutato; preflight rifiuta prima di ogni DDL;
    ripresa da DDL parziale; rollback rifiutato;
  - FK composte: store, terminale, account, store link di altro merchant o
    istanza rifiutati; terminale di altro negozio rifiutato; cancellazioni e
    spostamento del terminale mappato bloccati;
  - credenziali: busta B1a reale salvata in binario e decifrata; seconda
    `current` e promozione rifiutate; `pending/verified/retiring` convivono;
    busta incompleta, nonce/DEK corti, ciphertext senza tag o oltre limite,
    versione, KEK, impronta, tipo o stato ignoti rifiutati;
  - outbox: default, duplicato, `in_flight`/lease incompleti, operazione
    ignota, limiti;
  - GRANT: web senza alcun accesso alle credenziali, colonne non ammesse
    1143, nessun UPDATE/DELETE; INSERT outbox con rollback/commit insieme al
    negozio; worker scrive B1, niente DELETE/DDL/scritture Napay, legge solo
    le colonne concesse; nessun GRANT OPTION né privilegio sullo schema.
- `tests/docker/runtime.sh` completo (bootstrap con la nuova migration): verde.
- Lint PHP 8.3.36 sui 4 file PHP.

## Punti per il master (bootstrap/worker)

- **Web solo SQL esplicito sulle tabelle B1**: con privilegi solo a colonna
  `Command::insert()/update()` e ActiveRecord falliscono (Yii legge lo schema
  con `SHOW CREATE TABLE`, negato: 1142). Le letture con `Query` e SQL
  parametrico funzionano; `AccountEligibility` (ActiveQuery) gira con i soli
  GRANT a colonna del worker e dà risposte identiche.
- Aggiunta a §4: il web legge anche `instance` dei lavori (filtro del
  backoffice per istanza, indice `instance, merchant_id, created_at`).
- I GRANT del web sulle tabelle Napay devono restare **per tabella**: un
  GRANT su `napay.*` darebbe al web anche le credenziali.
- Matrice GRANT usata nel test: nel runner, da riportare nel bootstrap.
  Colonne Napay del worker: `users(id, email, is_active, privilege_id)`,
  `privileges(id, level)`, `member_profiles(user_id, is_corporate, denomination)`,
  `membership_payments(user_id)`, `pos_operators(user_id)`,
  `merchants(id, user_id)`, `stores(id, merchant_id)`,
  `pos_terminals(id, store_id, merchant_id)`; `logs` solo INSERT.
- Un terminale mappato non può cambiare negozio (FK RESTRICT): da gestire
  nel backoffice quando arriverà lo spostamento.

## Correzione review master (B1-B-REVIEW-MASTER, RV1)

- `ddcfadbc`: `information_schema` restituisce l'espressione con un livello
  di escape in più (`\'`, `\\`, verificato su MySQL 8.4.13): prima si toglie,
  poi si normalizzano spazi, backtick e introducer **solo fuori dai
  letterali**; i letterali restano byte per byte (spazi, backslash, escape),
  letterale non chiuso = incompatibile.
- `64d042fa`: derive solo nei letterali (marker `'cur rent'`, dominio con
  spazio, regex KEK con spazio e con backslash): ognuna rifiutata senza
  ricreare la tabella mancante, poi replay dello schema esatto accettato.
  B1b **148 PASS**, C1 55 PASS; con il verificatore precedente la suite
  fallisce alla prima deriva. `runtime.sh` completo verde.
- Nota fuori dal mio write set: `normalize()` di C1 e `clause()` di D tolgono
  anch'essi gli spazi ovunque; oggi i loro CHECK non hanno letterali stringa,
  quindi nessun effetto pratico.
