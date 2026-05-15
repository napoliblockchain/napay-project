# TIP-011 - Documentazione tecnica e operativa della nuova piattaforma

- Stato: OPEN
- Area: Docs
- Repo: `docs`
- Branch target: `feature/v2-docs-modernization`
- Segnalato: 2026-04-21

## Contesto
La documentazione attuale copre soprattutto manuali utente e note storiche. La migrazione v2 richiede documentazione tecnica operativa orientata a sviluppo, deploy, incident e manutenzione.

## Proposta
- Riorganizzare docs in sezioni:
  - architettura v2
  - setup locale docker
  - configurazione ambienti
  - runbook operativi
  - troubleshooting
  - changelog migrazione
- Mantenere collegamento con manuali utente esistenti.

## Criteri di accettazione
- Esiste guida unica per bootstrap ambiente da zero.
- Esistono runbook minimi per deploy, rollback, incident response.
- Ogni repo ha link a sezione docs tecnica corrispondente.

## Impatto
- Repo `docs`, onboarding team, operations quotidiane.

## Note implementative
- Usare convenzioni naming e versioning coerenti con branch/release v2.
- Preferire diagrammi semplici e checklist operative.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/docs/README.md`
- `/var/www/napay-project/docs/docs/updates-napay.md`
- `/var/www/napay-project/docs/docs/updates-pos.md`
- `/var/www/napay-project/docs/docs/updates-wallet.md`
- `/var/www/napay-project/docs/docs/updates-bolt.md`
