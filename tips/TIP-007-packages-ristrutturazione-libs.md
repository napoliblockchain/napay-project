# TIP-007 - Packages condivisi: da submodule legacy a dipendenze versionate

- Stato: OPEN
- Area: Shared Libraries
- Repo: `packages`
- Branch target: `feature/v2-shared-libs`
- Segnalato: 2026-04-21

## Contesto
`packages` e monorepo con submodule multipli (`.gitmodules`) usati trasversalmente da POS/Wallet/Bolt. L'accoppiamento via path filesystem rende fragile il deploy containerizzato e la gestione versioni.

## Proposta
- Definire librerie core da mantenere e librerie da dismettere.
- Convertire componenti necessari in pacchetti versionati (private registry o git tag).
- Ridurre dipendenze duplicate e path include hardcoded.
- Introdurre policy versioning semantico e changelog unificato.

## Criteri di accettazione
- Ogni app consuma librerie shared via dipendenze dichiarate, non include relativi a path host.
- Catalogo librerie core approvato (keep / refactor / retire).
- Lockfile e versioni riproducibili in CI.

## Impatto
- Repo `packages` e tutti i consumer (`pos`, `store-wallet`, `bolt`, `napay` se necessario).

## Note implementative
- Pianificare migrazione graduale: prima adapter compatibilita, poi rimozione include legacy.
- Valutare split in piu repo se i domini evolvono con cadenze diverse.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/packages/.gitmodules`
- `/var/www/napay-project/packages/README.md`
