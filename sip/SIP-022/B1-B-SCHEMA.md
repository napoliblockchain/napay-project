# SIP-022 B1b - Schema dati del provisioning (PROPOSTA, solo documento)

- Autore: agente Napay (CLA). Data: 2026-11-13. Assegnato dal master nel file
  di coordinamento (passo solo documentale).
- Riferimenti: [B1-PROPOSTA](B1-PROPOSTA.md) (flussi, sezioni 2-6),
  [B1a busta](B1-A-CIFRATURA.md), [decisione B](B1-DECISIONE-ROTAZIONE.md),
  migration C1 `m261112_130000` e D `m261112_140000` (stile e verifica).
- Stato: **proposta da rivedere.** Nessuna migration, codice, grant o DDL
  applicati. Timestamp, bootstrap, stack e privilegi effettivi: master.

## 1. Convenzioni (come C1 e D)

- MySQL 8.4, InnoDB, `utf8mb4` / `utf8mb4_0900_bin`; identificativi esterni
  e digest in `ascii_bin`.
- Tempi `BIGINT` Unix UTC in secondi, impostati dal servizio; CHECK
  `created_at >= 0 AND updated_at >= created_at`.
- FK tutte `ON DELETE RESTRICT ON UPDATE RESTRICT`; nessuna cascata.
- Stati come `VARCHAR` con CHECK sull'elenco ammesso (nessun `ENUM`).
- Tabelle nuove e vuote: nessun vincolo UNIQUE aggiunto a dati legacy.
  L'unica eccezione proposta è un indice su una tabella C1 vuota/nuova (3.4).
- Migration: preflight, `CREATE TABLE` unico per tabella con indici, FK e
  CHECK, ripresa solo su definizione identica, rollback distruttivo
  rifiutato, come C1 e D.
- Verificato su MySQL 8.4.13 usa-e-getta (sezione 6): FK composte, colonna
  generata, `REGEXP_LIKE` nei CHECK, privilegi a colonna.

`instance` = `CHAR(64) ascii_bin`, SHA-256 hex minuscolo dell'URL BTCPay
configurato (CHECK `REGEXP_LIKE(instance, '^[0-9a-f]{64}$', 'c')`), presente
in ogni tabella e in ogni FK composta: regtest e produzione non si mescolano.

## 2. Coerenza tenant e istanza

Catena di FK composte, ognuna verso una chiave UNIQUE (MySQL 8.4 lo esige):

```
merchants(id) <- accounts(merchant_id)
accounts(id, instance, merchant_id) <- credentials(account_id, instance, merchant_id)
accounts(id, instance, merchant_id) <- store_links(account_id, instance, merchant_id)
stores(id, merchant_id) <- store_links(store_id, merchant_id)            [uq-pos-stores-id-merchant, C1]
store_links(id, instance, merchant_id, store_id) <- pos_links(store_link_id, instance, merchant_id, store_id)
pos_terminals(id, store_id, merchant_id) <- pos_links(terminal_id, store_id, merchant_id)  [nuovo UNIQUE, 3.4]
```

Un mapping non può quindi puntare a un negozio, terminale o account di un
altro merchant o di un'altra istanza, nemmeno con scritture fuori dal codice.

## 3. Tabelle

### 3.1 `btcpay_merchant_accounts`

| Colonna | Tipo | Null | Default | Note |
| --- | --- | --- | --- | --- |
| `id` | INT AUTO_INCREMENT | no | | PK |
| `instance` | CHAR(64) ascii_bin | no | | |
| `merchant_id` | INT | no | | FK `merchants.id` |
| `ref` | CHAR(32) ascii_bin | no | | casuale (16 byte hex), CHECK `^[0-9a-f]{32}$` |
| `technical_email` | VARCHAR(255) ascii_bin | no | | `m-<ref>@btcpay-merchants.jamprojects.it`, CHECK suffisso e lunghezza |
| `remote_user_id` | VARCHAR(64) ascii_bin | sì | NULL | id utente BTCPay, CHECK 1..64 se presente |
| `state` | VARCHAR(24) | no | `pending` | `pending`, `user_requested`, `user_created`, `key_saved`, `synced`, `suspended`, `reconcile_required`, `failed` |
| `key_generations_used` | SMALLINT | no | 0 | CHECK 0..1000; limite per tentativo nel worker |
| `last_error_code` | VARCHAR(64) ascii_bin | sì | NULL | solo codici (`^[a-z0-9_]{1,64}$`), mai testo libero |
| `version` | INT | no | 0 | CAS |
| `created_at`, `updated_at` | BIGINT | no | | |

Chiavi: UNIQUE (`instance`, `merchant_id`) un account per merchant e istanza;
UNIQUE `ref`; UNIQUE (`instance`, `technical_email`); UNIQUE (`instance`,
`remote_user_id`); UNIQUE (`id`, `instance`, `merchant_id`) per le FK composte.
Nessun segreto.

### 3.2 `btcpay_merchant_credentials` (solo worker)

Una riga per segreto e generazione; busta B1a memorizzata in binario
(base64 solo al confine dell'helper).

| Colonna | Tipo | Null | Note |
| --- | --- | --- | --- |
| `account_id`, `instance`, `merchant_id` | INT, CHAR(64), INT | no | FK composta verso accounts |
| `kind` | VARCHAR(32) ascii_bin | no | `onboarding_password` (password tecnica permanente, decisione B) o `api_key` |
| `generation` | INT | no | CHECK >= 1 |
| `state` | VARCHAR(16) | no | `pending`, `verified`, `current`, `retiring`, `revoked` |
| `current_marker` | TINYINT generata STORED | sì | `CASE WHEN state = 'current' THEN 1 END` |
| `envelope_version` | TINYINT | sì | CHECK = 1 |
| `kek_version` | VARCHAR(64) ascii_bin | sì | CHECK `^[A-Za-z0-9_-]{1,64}$` |
| `secret_nonce` | BINARY(24) | sì | |
| `ciphertext` | VARBINARY(16400) | sì | CHECK lunghezza 17..16400 |
| `dek_nonce` | BINARY(24) | sì | |
| `wrapped_dek` | BINARY(48) | sì | |
| `key_fingerprint` | CHAR(64) ascii_bin | sì | SHA-256 hex, solo `api_key` |
| `lock_version` | INT | no | CAS, default 0 |
| `created_at`, `updated_at` | BIGINT | no | |

Chiavi e CHECK:
- PK (`account_id`, `kind`, `generation`);
- UNIQUE (`account_id`, `kind`, `current_marker`): **al massimo una riga
  `current`** per account e tipo, mentre `pending`, `verified` e `retiring`
  convivono (verificato, sezione 6);
- busta completa (tutti i campi busta non nulli) per ogni stato diverso da
  `revoked`; per `revoked` busta azzerata (tutti NULL), riga conservata per
  l'audit della generazione;
- `key_fingerprint` non nullo solo per `api_key` non revocate;
- INDEX (`instance`, `merchant_id`) per le FK.

### 3.3 `btcpay_store_links`

| Colonna | Tipo | Null | Note |
| --- | --- | --- | --- |
| `id` | INT AUTO_INCREMENT | no | PK |
| `instance`, `account_id`, `merchant_id`, `store_id` | | no | FK composte (sezione 2) |
| `marker` | CHAR(32) ascii_bin | no | casuale, UNIQUE, entra nel nome remoto |
| `remote_store_id` | VARCHAR(64) ascii_bin | sì | |
| `state` | VARCHAR(24) | no | `pending`, `synced`, `reconcile_required`, `failed`, `suspended` |
| `last_error_code`, `version`, `created_at`, `updated_at` | | | come 3.1 |

Chiavi: UNIQUE (`instance`, `store_id`) uno store BTCPay per negozio;
UNIQUE (`instance`, `remote_store_id`); UNIQUE (`id`, `instance`,
`merchant_id`, `store_id`) per le app POS; CHECK: `synced` implica
`remote_store_id` non nullo.

### 3.4 `btcpay_pos_links`

Come 3.3 con `store_link_id`, `terminal_id`, `remote_app_id`; UNIQUE
(`instance`, `terminal_id`), UNIQUE (`instance`, `remote_app_id`), UNIQUE
`marker`; `synced` implica `remote_app_id` non nullo.

**FK verso il terminale.** Per la coerenza negozio/merchant serve
UNIQUE (`id`, `store_id`, `merchant_id`) su `pos_terminals` (tabella C1).
L'indice è sempre soddisfatto (`id` è già PK) ma tocca una tabella C1:
**decisione del master**. Alternativa senza toccare C1: FK solo su
`pos_terminals.id` e coerenza verificata dal worker sotto lock (più debole:
non protegge da scritture fuori dal codice).

### 3.5 `btcpay_provisioning_jobs` (outbox, nessun segreto)

| Colonna | Tipo | Null | Default | Chi scrive |
| --- | --- | --- | --- | --- |
| `id` | BIGINT AUTO_INCREMENT | no | | |
| `kind` | VARCHAR(32) ascii_bin | no | | web, worker: `merchant_account`, `store_link`, `pos_link`, `key_rotation`, `key_revoke` |
| `instance` | CHAR(64) ascii_bin | no | | web, worker |
| `merchant_id` | INT | no | | web, worker (per scope e backoffice) |
| `entity_id` | INT | no | | web, worker: ID Napay (merchant, negozio o terminale) |
| `generation` | INT | no | 1 | web, worker: nuova riga per "riprova" |
| `requested_by` | INT | sì | NULL | web: admin che ha chiesto la riprova (FK `users.id`) |
| `state` | VARCHAR(24) | no | `pending` | worker: `pending`, `running`, `in_flight`, `retry_wait`, `deferred`, `reconcile_required`, `failed`, `done` |
| `attempts` | SMALLINT | no | 0 | worker, CHECK 0..1000 |
| `next_attempt_at` | BIGINT | no | 0 | worker |
| `lease_owner` | CHAR(36) ascii_bin | sì | NULL | worker (UUID del processo) |
| `lease_until` | BIGINT | sì | NULL | worker |
| `in_flight_op` | VARCHAR(32) ascii_bin | sì | NULL | worker, CHECK elenco operazioni |
| `in_flight_started_at`, `in_flight_owner` | BIGINT, CHAR(36) | sì | NULL | worker |
| `version` | INT | no | 0 | worker, CAS |
| `last_error_code` | VARCHAR(64) ascii_bin | sì | NULL | worker, solo codici |
| `created_at`, `updated_at` | BIGINT | no | | web e worker |

Chiavi: UNIQUE (`kind`, `instance`, `entity_id`, `generation`); INDEX
(`state`, `next_attempt_at`) per la presa con `SKIP LOCKED`; INDEX
(`instance`, `merchant_id`, `created_at`) per il backoffice.
CHECK: `in_flight` implica `in_flight_op`, `in_flight_started_at` e
`in_flight_owner` non nulli; lease completa o assente (owner e scadenza
insieme). Nessuna colonna per payload libero: tipo + ID soltanto.

## 4. Privilegi

Tre utenti DB distinti (creazione e GRANT nel bootstrap del master).

| Oggetto | migrator (proprietario) | web | worker |
| --- | --- | --- | --- |
| DDL, GRANT | sì | no | no |
| `btcpay_merchant_credentials` | — | **nessuno** | SELECT, INSERT, UPDATE |
| `btcpay_merchant_accounts` | — | SELECT (`id`, `instance`, `merchant_id`, `state`, `last_error_code`, `updated_at`) | SELECT, INSERT, UPDATE |
| `btcpay_store_links`, `btcpay_pos_links` | — | SELECT (id, chiavi Napay, `state`, `last_error_code`, `updated_at`) | SELECT, INSERT, UPDATE |
| `btcpay_provisioning_jobs` | — | **INSERT** (`kind`, `instance`, `merchant_id`, `entity_id`, `generation`, `requested_by`, `created_at`, `updated_at`); SELECT (`id`, `kind`, `merchant_id`, `entity_id`, `generation`, `state`, `attempts`, `next_attempt_at`, `last_error_code`, `created_at`, `updated_at`) | SELECT, INSERT, UPDATE |
| Tabelle Napay per i ricontrolli (`merchants`, `stores`, `pos_terminals`, `users`, `privileges`, `member_profiles`, `membership_payments`, `pos_operators`) | — | invariato | solo SELECT, sulle colonne lette da `AccountEligibility` e dal ricontrollo tenant |
| `logs` (audit) | — | invariato | INSERT |

- Nessun `DELETE` per gli utenti applicativi sulle tabelle B1 (revoca =
  busta azzerata con UPDATE; righe conservate).
- Il web non può scrivere stato, lease, `in_flight` o versione dei lavori:
  la riga nasce con i default `pending`, `version = 0`.
- L'elenco colonne del worker sulle tabelle Napay va derivato dalle query
  effettive di `AccountEligibility` prima della migration (punto aperto).

## 5. Test previsti (DB usa-e-getta, prima dell'integrazione)

- Schema: preflight, creazione, ripresa identica, definizione diversa
  rifiutata, rollback rifiutato (come C1/D).
- FK composte: account, store, terminale di altro merchant o altra istanza
  rifiutati; terminale di altro negozio rifiutato (con l'indice 3.4).
- Credenziali: seconda `current` per lo stesso account/tipo rifiutata;
  `pending`/`retiring` convivono; busta incompleta rifiutata; `revoked` con
  busta rifiutata; `kind` ignoto rifiutato.
- Outbox: `in_flight` incompleto rifiutato; lease parziale rifiutata;
  duplicato (tipo, istanza, entità, generazione) rifiutato.
- Privilegi, con utenti reali sul DB usa-e-getta:
  - web: qualunque accesso a `btcpay_merchant_credentials` rifiutato;
    `INSERT` in outbox ammesso solo sulle colonne elencate, rifiutato su
    `state`, `lease_owner`, `version`; `UPDATE`/`DELETE` rifiutati su tutte
    le tabelle B1; `SELECT` di colonne non elencate rifiutata;
  - web: `INSERT` in outbox dentro la stessa transazione di un'attivazione
    merchant o creazione negozio, con rollback di entrambi;
  - worker: letture e scritture B1 ammesse, `DELETE` e DDL rifiutati;
    scrittura su tabelle Napay rifiutata;
  - nessun utente applicativo con `GRANT OPTION`.

## 6. Verifiche già eseguite (MySQL 8.4.13 usa-e-getta, nessun dato reale)

- FK composta verso colonne con indice non univoco: rifiutata (errore 6125,
  `restrict_fk_on_non_standard_key = 1`); quindi le chiavi UNIQUE della
  sezione 2 sono necessarie.
- Colonna generata `current_marker` + UNIQUE: una `current` e altre
  generazioni `pending`/`retiring` accettate; seconda `current` rifiutata
  (errore 1062).
- CHECK con `REGEXP_LIKE`: valore fuori elenco rifiutato (errore 3819).
- Privilegi a colonna: `INSERT` sulle colonne ammesse riuscito; `INSERT`
  su `lease_owner` rifiutato (1143); `UPDATE` rifiutato (1142); `SELECT` di
  colonna non ammessa rifiutata (1143); tabella credenziali senza privilegi
  rifiutata (1142).

## 7. Punti per il master

- Indice UNIQUE (`id`, `store_id`, `merchant_id`) su `pos_terminals` (3.4)
  o alternativa più debole.
- Timestamp delle migration B1 e ordine rispetto a quelle in corso.
- Creazione dei tre utenti DB, GRANT e loro collaudo nel bootstrap/stack.
- Elenco colonne delle tabelle Napay lette dal worker.
