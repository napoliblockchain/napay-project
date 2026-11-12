# SIP-010 - CI/CD, branching e processo release multi-repo

- Stato: OPEN
- Area: Delivery
- Repo: `napay, pos, store-wallet, bolt, packages, docs`
- Branch target: `feature/v2-*`
- Segnalato: 2026-04-21

## Contesto
Il programma e multi-repo. Senza pipeline allineata e branch policy comune, il rilascio coordinato della v2 diventa fragile.

## Proposta
- Definire strategy branch comune:
  - `feature/v2-*`
  - `release/v2.*`
  - `hotfix/v2.*`
- Introdurre pipeline standard per ogni repo:
  - lint
  - test unit/integration
  - build immagini
  - security scan
- Definire release train con tag coerenti cross-repo.

## Criteri di accettazione
- Ogni repo ha workflow CI con gate minimi obbligatori.
- Le immagini Docker vengono versionate e pubblicate in modo ripetibile.
- Esiste checklist release condivisa per go-live.

## Impatto
- Repository code + infrastruttura CI/CD + runbook rilascio.

## Note implementative
- Non bloccare migrazione su copertura test totale immediata: usare threshold incrementali.
- Aggiungere environment promotion automatica da staging a prod con approvazione.

## Verifica repository
- Da completare durante setup pipeline.
