# TIP - Technical Improvement Proposals Napay

Le TIP (Technical Improvement Proposal) documentano il piano di ammodernamento completo della piattaforma Napay verso:
- orchestrazione Docker full-stack
- eliminazione dipendenza runtime da Yii 1.x
- allineamento applicativo a Yii2 + PHP 8.3

Questo README e indice operativo. Ogni scheda e nel file dedicato `TIP-XXX-*.md` in questa cartella.

## Indice (ordinato per dipendenze)

| ID | Titolo | Area | Stato |
| -- | ------ | ---- | ----- |
| [TIP-001](TIP-001-inventario-perimetro-software.md) | Inventario software e perimetro tecnico Napay | Architettura | COMPLETED |
| [TIP-002](TIP-002-piattaforma-docker-unificata.md) | Piattaforma Docker unificata | DevOps / Runtime | OPEN |
| [TIP-003](TIP-003-napay-yii2-php83-hardening.md) | Napay Backoffice: hardening Yii2 su PHP 8.3 | Backoffice | IN_PROGRESS |
| [TIP-004](TIP-004-pos-porting-yii1-yii2.md) | POS: porting da Yii1 a Yii2 | POS | OPEN |
| [TIP-005](TIP-005-store-wallet-porting-yii1-yii2.md) | Store Wallet: porting da Yii1 a Yii2 | Wallet Merchant | OPEN |
| [TIP-006](TIP-006-bolt-porting-yii1-yii2.md) | Bolt: porting da Yii1 a Yii2 | Wallet Cittadino Legacy | REJECTED |
| [TIP-007](TIP-007-packages-ristrutturazione-libs.md) | Packages condivisi: da submodule legacy a dipendenze versionate | Shared Libraries | OPEN |
| [TIP-008](TIP-008-sicurezza-segreti-configurazione.md) | Sicurezza: secret management e configurazioni sensibili | Security | OPEN |
| [TIP-009](TIP-009-database-contratti-api.md) | Database e contratti API tra applicazioni | Data / Integration | OPEN |
| [TIP-010](TIP-010-ci-cd-branching-release.md) | CI/CD, branching e processo release multi-repo | Delivery | OPEN |
| [TIP-011](TIP-011-documentazione-operativa.md) | Documentazione tecnica e operativa della nuova piattaforma | Docs | OPEN |
| [TIP-012](TIP-012-dismissione-yii1-runtime.md) | Dismissione runtime Yii 1.1.22 | Decommission | OPEN |
| [TIP-013](TIP-013-selezione-base-wallet-eth-poa.md) | Scelta base wallet ETH/POA tra Bolt, Poawallet e Tokenpay | Wallet Architecture | COMPLETED |
| [TIP-014](TIP-014-piano-unificazione-poawallet-tokenpay.md) | Piano unificazione: base Poawallet + moduli Tokenpay | Wallet Delivery | IN_PROGRESS |
| [TIP-015](TIP-015-policy-archiviazione-repository.md) | Policy archiviazione repository non core | Governance | COMPLETED |
| [TIP-016](TIP-016-porte-container-e-repo-orchestratore.md) | Piano porte container non standard e repo orchestratore unico | Platform Governance / DevOps | IN_PROGRESS |
| [TIP-017](TIP-017-blockchain-poa-besu-ttstoken.md) | Blockchain POA: Hyperledger Besu IBFT 2.0 + TTS Token deploy | Blockchain Infrastructure | OPEN |

Legenda stati: OPEN | VERIFY | IN_PROGRESS | COMPLETED | REJECTED

## Verifica iniziale repository

Perimetro software rilevato in `/var/www/napay-project`:
- `napay` (Yii2, branch `feature/v2-yii2-php83-docker`, `composer` con `php >=7.4`, Dockerfile base `php:8.2-apache`)
- `pos` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`)
- `store-wallet` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`)
- `bolt` (Yii1, bootstrap `index.php` con `../yii-1.1.22/framework/yii.php`, candidato archive)
- `poawallet` (Yii2, wallet con flow send completo e supporto POA, base attiva)
- `tokenpay` (Yii2, evoluzione architetturale con moduli admin/network, sorgente merge selettivo)
- `packages` (monorepo di librerie e submodule)
- `docs` (manuali e note funzionali)
- `yii-1.1.22` (framework legacy usato dai repo Yii1)
- `ttstoken` ([napoliblockchain/ttstoken](https://github.com/napoliblockchain/ttstoken.git)) - token ERC20 TTS su blockchain POA Besu, VPS separata, vedi TIP-017

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

## Come gestire una TIP

1. Assegna il prossimo ID progressivo.
2. Crea `TIP-0XX-descrizione-breve.md` partendo da [`TEMPLATE.md`](TEMPLATE.md).
3. Aggiorna indice in questo README.
4. Mantieni allineate note implementative con stato reale dei repository.

## Convenzioni

- Naming branch: `feature/v2-*` per sviluppo, `release/v2.*` per preparazione rilascio.
- Naming immagini Docker: `napay/<repo>:<versione>`.
- Naming container service: `<dominio>-<ruolo>` (es. `wallet-web`, `wallet-worker`).
- Naming docs tecniche: file markdown in questa cartella con formato `TIP-XXX-*`.
