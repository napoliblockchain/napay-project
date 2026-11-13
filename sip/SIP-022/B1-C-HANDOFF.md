# SIP-022 B1c - Handoff coda worker (agente Napay, 2026-11-13)

- Via libera: `sip/SIP-022/B1-C-CODA.md` (orchestratore, `0e0ac0c`).
- Worktree `napay-worktrees/napay-btcpay-b1c`, branch
  `feature/v2-btcpay-b1c-queue`, base `7be3a3e0`. Commit: `f447733a`
  (componente), `00b0d2c8` (test).
- Nessun push/merge, HTTP, console, controller, schema, GRANT o bootstrap.

## Componente

`components/btcpay/provisioning/ProvisioningJobs.php`: Connection iniettata,
owner UUID v4, lease 1..3600 s, orologio iniettabile; solo SQL parametrico.

| Metodo | Transizione |
| --- | --- |
| `claim(instance)` | transazione propria READ COMMITTED, `FOR UPDATE SKIP LOCKED`, primo lavoro dovuto dell'istanza senza lease valida (`deferred` mai: richiede admin) -> `running` + lease, tentativo +1; restituisce solo ID, tipo, istanza, merchant, entità, generazione, tentativi, versione, scadenza |
| `checkpoint(id, version, op)` | `running` senza marker -> `in_flight`, lease rinnovata |
| `succeed` / `fail(code)` | `running`/`in_flight` -> `done`/`failed`, lease e marker azzerati |
| `reconcile(code)` | -> `reconcile_required`, marker conservati |
| `remoteRejected(status)` | `in_flight` -> `running` solo con 429 (prova di mancata esecuzione, B0) |
| `retryLater(code, at, deferred)` | solo da `running` senza marker -> `retry_wait` all'istante dato, o `deferred` (poi solo admin) |

- Ogni esito: una UPDATE CAS su ID, owner, versione, stato e lease non
  scaduta; restituisce la nuova versione o `null` (esito tardivo scartato).
- Nella presa: marker in volo con lease scaduta o assente, **qualunque stato
  attivo** -> `reconcile_required` (`in_flight_expired`), mai ripreso;
  `running` scaduto senza marker -> ripreso da un altro owner; 1000
  tentativi -> `failed` (`attempts_exhausted`).
- Con una transazione del chiamante aperta ogni metodo rifiuta
  (`caller_transaction_open`). Input non validi: codici fissi, mai l'input.

## Test (DB e utente worker usa-e-getta, matrice GRANT B1b)

`tests/docker/btcpay-provisioning-jobs.sh`: **57 PASS**, bootstrap no-op.
Due connessioni worker reali e due processi concorrenti: SKIP LOCKED senza
attesa (timeout lock 1 s), un solo vincitore, istanze isolate, CAS del
checkpoint (versione/owner), 429 -> retry, retry/deferred non presi prima
del tempo, esito tardivo e vecchio owner respinti, in volo scaduto mai
ripreso, marker con stato `running`/`pending`/`retry_wait` in
riconciliazione, input non validi, nessun segreto/log nel sorgente.
Controprova con mutazioni del componente: senza `SKIP LOCKED` (attesa lock),
senza controllo lease nel CAS, senza ramo marker -> la suite fallisce.
Runtime completa non rieseguita: nessun file esistente modificato.

## Correzioni review master (RV1/RV2)

- `fcf2fd5f`: `deferred` non è mai preso, nemmeno dopo `next_attempt_at`
  (SIP B1 §4: richiede l'admin); la presa considera solo righe senza lease
  valida, quindi un marker su `pending`/`retry_wait` con owner attivo resta
  intatto e va in riconciliazione solo a lease scaduta.
- `0ff5fbf0`: `deferred` già dovuto ignorato da entrambi i worker; marker
  `pending`/`retry_wait` con lease futura invariati, dopo la scadenza solo
  `reconcile_required` e nessuna nuova presa. **63 PASS**. Controprova: il
  componente precedente fallisce su RV1; con il solo fix RV1 fallisce su RV2.

## Limiti

- Non serializza la risorsa: lock del mapping e ricontrolli tenant/idoneità
  restano all'orchestratore, prima di ogni chiamata esterna.
- Nessun rinnovo della lease oltre il checkpoint, nessun calcolo dell'attesa
  (backoff, Retry-After) e nessuna creazione di lavori: al chiamante.
- `fail` da `in_flight` va usato solo con esito remoto noto e definitivo.
