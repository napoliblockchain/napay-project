# SIP - Proposte di aggiornamento Napay

I SIP documentano il piano di ammodernamento completo della piattaforma Napay verso:
- orchestrazione Docker full-stack
- eliminazione dipendenza runtime da Yii 1.x
- allineamento applicativo a Yii2 + PHP 8.3

Questo README e indice operativo. Ogni scheda e nel file dedicato `SIP-XXX-*.md` in questa cartella.

## Standard documentale

Dal 2026-11-12 la cartella canonica e `sip/` e tutti gli identificativi usano
il prefisso `SIP-`. Numerazione, contenuti e stati precedenti restano preservati;
la rinomina non implica nuove approvazioni. Anche gli allegati seguono `SIP-NNN/`.
Riferimenti storici TIP nei vecchi commit restano parte della cronologia Git.

## Indice (ordinato per dipendenze)

Piano condiviso Napay/POS, ownership file e obiettivo 23/11/2026:
[COORDINAMENTO.md](COORDINAMENTO.md).

| ID | Titolo | Area | Stato |
| -- | ------ | ---- | ----- |
| [SIP-001](SIP-001-inventario-perimetro-software.md) | Inventario software e perimetro tecnico Napay | Architettura | COMPLETED |
| [SIP-002](SIP-002-piattaforma-docker-unificata.md) | Piattaforma Docker unificata | DevOps / Runtime | OPEN |
| [SIP-003](SIP-003-napay-yii2-php83-hardening.md) | Napay Backoffice: hardening Yii2 su PHP 8.3 | Backoffice | IN_PROGRESS |
| [SIP-004](SIP-004-pos-porting-yii1-yii2.md) | POS: porting da Yii1 a Yii2 | POS | IN_PROGRESS |
| [SIP-005](SIP-005-store-wallet-porting-yii1-yii2.md) | Store Wallet: porting da Yii1 a Yii2 | Wallet Merchant | OPEN |
| [SIP-006](SIP-006-bolt-porting-yii1-yii2.md) | Bolt: porting da Yii1 a Yii2 | Wallet Cittadino Legacy | REJECTED |
| [SIP-007](SIP-007-packages-ristrutturazione-libs.md) | Packages condivisi: da submodule legacy a dipendenze versionate | Shared Libraries | OPEN |
| [SIP-008](SIP-008-sicurezza-segreti-configurazione.md) | Sicurezza: secret management e configurazioni sensibili | Security | OPEN |
| [SIP-009](SIP-009-database-contratti-api.md) | Database e contratti API tra applicazioni | Data / Integration | OPEN |
| [SIP-010](SIP-010-ci-cd-branching-release.md) | CI/CD, branching e processo release multi-repo | Delivery | OPEN |
| [SIP-011](SIP-011-documentazione-operativa.md) | Documentazione tecnica e operativa della nuova piattaforma | Docs | OPEN |
| [SIP-012](SIP-012-dismissione-yii1-runtime.md) | Dismissione runtime Yii 1.1.22 | Decommission | OPEN |
| [SIP-013](SIP-013-selezione-base-wallet-eth-poa.md) | Scelta base wallet ETH/POA tra Bolt, Poawallet e Tokenpay | Wallet Architecture | COMPLETED |
| [SIP-014](SIP-014-piano-unificazione-poawallet-tokenpay.md) | Piano unificazione: base Poawallet + moduli Tokenpay | Wallet Delivery | COMPLETED |
| [SIP-015](SIP-015-policy-archiviazione-repository.md) | Policy archiviazione repository non core | Governance | COMPLETED |
| [SIP-016](SIP-016-porte-container-e-repo-orchestratore.md) | Piano porte container non standard e repo orchestratore unico | Platform Governance / DevOps | IN_PROGRESS |
| [SIP-017](SIP-017-blockchain-poa-besu-ttstoken.md) | Blockchain POA: Hyperledger Besu IBFT 2.0 + TTS Token deploy | Blockchain Infrastructure | OPEN |
| [SIP-018](SIP-018-napay-migrazione-tabler.md) | Napay: migrazione AdminLTE a Tabler, riferimento Aura | Backoffice / UI | IN_PROGRESS |
| [SIP-019](SIP-019-napay-mysql-persistenza-migrazione.md) | Napay: MySQL dedicato, persistenza e ripristino dati v2 | Backoffice / Database | IN_PROGRESS |
| [SIP-020](SIP-020-napay-ripristino-associazione-legacy.md) | Napay: ripristino gestione associazione e migrazione dati legacy | Backoffice / Associazione | IN_PROGRESS |
| [SIP-021](SIP-021-pos-login-operatori-apertura-esclusiva.md) | POS: login operatori, negozi autorizzati e apertura esclusiva | POS / Napay / Integrazione | OPEN |
| [SIP-022](SIP-022-provisioning-merchant-store-pos-btcpay.md) | Provisioning automatico merchant, negozi e POS su BTCPay | Napay / BTCPay / Integrazione | OPEN |
| [SIP-023](SIP-023-profili-soci-merchant-operatori.md) | Separazione soci PF/PG, gestori merchant e operatori POS | Identita / Associazione / Autorizzazioni | OPEN |
| [SIP-024](SIP-024-websocket-nodejs-notifiche.md) | WebSocket Node.js al posto del motore socket PHP | Realtime / Docker / Sicurezza | OPEN |
| [SIP-025](SIP-025-napay-menu-macroaree-amministrazione.md) | Menu per macroaree e amministrazione per sezioni | Backoffice / Navigazione | IMPLEMENTED |
| [SIP-026](SIP-026-napay-dashboard-grafici.md) | Dashboard con grafici per ruolo | Backoffice / Reportistica | OPEN |

Legenda stati: OPEN | VERIFY | IN_PROGRESS | COMPLETED | REJECTED

## Verifica iniziale repository

Perimetro software rilevato in `/var/www/napay-project`:
- `napay` (Yii2, branch `feature/v2-yii2-php83-docker`, `composer` con `php >=7.4`, Dockerfile base `php:8.2-apache`)
- `pos` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`)
- `store-wallet` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`)
- `bolt` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`, candidato archive)
- `poawallet` (Yii2, wallet con flow send completo e supporto POA, base attiva)
- `tokenpay` (Yii2, prototipo; ARCHIVED 2026-10-23, moduli utili portati in `poawallet`)
- `packages` (monorepo di librerie e submodule)
- `docs` (manuali e note funzionali)
- `yii-1.1.22` (framework legacy usato dai repo Yii1)
- `ttstoken` ([napoliblockchain/ttstoken](https://github.com/napoliblockchain/ttstoken.git)) - token ERC20 TTS su blockchain POA Besu, VPS separata, vedi SIP-017

Criticita emerse:
- configurazioni sensibili hardcoded in file legacy
- dipendenza da librerie legacy non allineate a PHP 8.3
- worktree locali gia sporche in piu repository, da gestire senza reset distruttivi
- divergenza funzionale tra `poawallet` e `tokenpay` (routing send non completo su tokenpay)

## Strategia branch per nuova versione

Ogni repository ha branch dedicato sviluppo v2:

| Repository | Remote | Branch corrente | Branch target v2 |
| -- | -- | -- | -- |
| `napay` | `napoliblockchain/napay` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `pos` | `napoliblockchain/pos` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `store-wallet` | `napoliblockchain/store-wallet` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `bolt` | `napoliblockchain/bolt` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `poawallet` | `napoliblockchain/poawallet` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `tokenpay` | `napoliblockchain/tokenpay` | `feature/v2-yii2-php83-docker` | `feature/v2-yii2-php83-docker` |
| `packages` | `jambtc/packages` | `feature/v2-shared-libs` | `feature/v2-shared-libs` |
| `docs` | `napoliblockchain/napay-docs` | `feature/v2-docs-modernization` | `feature/v2-docs-modernization` |

## Ordine esecuzione (macro)

1. Step 1 - Wallet Foundation: base `poawallet`, merge selettivo moduli `tokenpay`, policy archive attiva.
2. Step 2 - Platform governance: matrice porte non standard + `napay-project` repo orchestratore unico.
3. Step 3 - Docker platform unificata per servizi wallet + napay.
4. Step 4 - Hardening PHP 8.3 e sicurezza/segreti.
5. Step 5 - Integrazione `napay` su wallet consolidato.
6. Step 6 - Porting progressivo repo Yii1 residui e dismissione runtime legacy.

## Criteri guida

- Architettura target: stack Docker con rete privata e servizi separati (app, worker, scheduler, db, cache, reverse proxy, observability).
- Backend target: PHP 8.3 e Yii2 per tutte le webapp.
- Shared code: eliminare accoppiamento filesystem e introdurre dipendenze versionate.
- Config: zero segreti nel codice; solo env/secret manager.
- Compatibilita: mantenere parity funzionale tra legacy e v2 prima del cutover.
- Rollout: migrazione progressiva per repo, con gate di test e smoke end-to-end.

## Come gestire una SIP

### SIP Prima Dell'Implementazione

Regola confermata dall'utente il 2026-11-11: prima documentare il SIP, poi
implementare. Per ogni nuovo intervento funzionale o architetturale:

1. Creare o aggiornare il SIP con contesto, decisioni, criteri verificabili,
   impatti, dipendenze, sicurezza e punti ancora da concordare.
2. Ottenere approvazione del perimetro e delle scelte necessarie alla fase.
   Una bozza API o un documento tecnico non equivale a SIP approvato.
3. Implementare solo la fase documentata, con piccoli commit e test pertinenti.
4. Riportare evidenze, limiti e stato reale; nuove decisioni tornano prima nel SIP.

Per il POS il riferimento funzionale e SIP-021; SIP-004 resta il piano generale
di porting. Lo stato OPEN non autorizza da solo l'implementazione.

1. Assegna il prossimo ID progressivo.
2. Crea `SIP-0XX-descrizione-breve.md` partendo da [`TEMPLATE.md`](TEMPLATE.md).
3. Aggiorna indice in questo README.
4. Mantieni allineate note implementative con stato reale dei repository.

## Convenzioni

- Naming branch: `feature/v2-*` per sviluppo, `release/v2.*` per preparazione rilascio.
- Naming immagini Docker: `napay/<repo>:<versione>`.
- Naming container service: `<dominio>-<ruolo>` (es. `wallet-web`, `wallet-worker`).
- Naming docs tecniche: file markdown in questa cartella con formato `SIP-XXX-*`.
