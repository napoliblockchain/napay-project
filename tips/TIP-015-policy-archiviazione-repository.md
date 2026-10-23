# TIP-015 - Policy archiviazione repository non core

- Stato: COMPLETED
- Area: Governance
- Repo: `bolt, tokenpay, poawallet, packages, store-wallet`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Per ridurre dispersione sviluppo, servono regole chiare su quali repo restano attivi e quali vanno in archive.

## Proposta
Policy operativa:
- `poawallet` = ACTIVE (repo base wallet)
- `tokenpay` = ARCHIVED (2026-10-23: estrazione moduli conclusa, vedi TIP-014; sostituito da `poawallet`)
- `bolt` = ARCHIVE_NOW (freeze immediato, solo riferimento storico)
- `packages` = DISMISSIONE (eliminare accoppiamento submodule filesystem; librerie versionate via composer/npm - vedi TIP-007)
- `store-wallet` = DA_VALUTARE (vedi sezione sotto)

Regole archive:
- nessun nuovo sviluppo funzionale su repo marcati archive
- solo fix di emergenza sicurezza, se indispensabili
- README del repo archiviato deve indicare “archived” e repo attivo sostitutivo

## Criteri di accettazione
- Esiste mappa stato repo wallet con ownership chiara.
- `bolt` non riceve nuove feature task.
- `tokenpay` usato solo come sorgente import moduli verso `poawallet`.

## Impatto
- Riduzione branch attivi e complessita decisionale.
- Maggiore velocita su roadmap wallet v2.

## Note implementative
Archive fisico (spostamento cartella o remote archiving) viene fatto solo dopo:
1. estrazione moduli utili da `tokenpay` conclusa,
2. smoke test wallet su `poawallet` verde.

`packages` dismesso dopo che ogni repo che lo consuma ha migrato le dipendenze a versionate (vedi TIP-007).

## Valutazione store-wallet vs poawallet

**Domanda aperta**: poawallet puo sostituire store-wallet o serve una versione dedicata merchant/business?

Scenari possibili:

### A - Wallet unico (poawallet rimpiazza store-wallet)

- Pro: una sola codebase, manutenzione centralizzata, feature wallet sempre allineate.
- Contro: serve supporto multi-tenant o multi-profilo dentro poawallet (es. ruolo merchant vs citizen).
- Quando ha senso: se store-wallet e solo un sottoinsieme di funzionalita di poawallet.

### B - Wallet separati (client vs business)

- Pro: UX e permessi separati per caso d'uso, release cycle indipendente.
- Contro: duplicazione codice, divergenza wallet, doppia manutenzione.
- Quando ha senso: se store-wallet ha logica business specifica (es. POS, split payment, riconciliazione) non riconducibile al wallet cittadino.

### C - poawallet con modulo merchant

- Pro: codebase unica, feature merchant come modulo opzionale (es. `/store` prefix route).
- Contro: richiede RBAC ben strutturato e layout/UX biforcata.
- Quando ha senso: se la differenza e solo di UI e permessi, non di dominio.

### Impatto da valutare prima di decidere

- Quali funzionalita ha store-wallet che poawallet non ha? (esaminare `store-wallet/` vs `poawallet/`)
- Il flow POS presuppone un wallet merchant separato o puo essere il wallet principale?
- Come napay (backoffice) aggancia il wallet del merchant? Via API? Via DB condiviso?

Decisione rimandata a dopo Step 1.4, quando poawallet e piu stabile. Aprire valutazione come TIP separata se l'analisi e complessa.

## Verifica repository
- `/var/www/napay-project/tips/TIP-013-selezione-base-wallet-eth-poa.md`
- `/var/www/napay-project/tips/TIP-014-piano-unificazione-poawallet-tokenpay.md`
- `/var/www/napay-project/bolt`
- `/var/www/napay-project/poawallet`
- `/var/www/napay-project/tokenpay`
