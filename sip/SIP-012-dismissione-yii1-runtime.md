# SIP-012 - Dismissione runtime Yii 1.1.22

- Stato: OPEN
- Area: Decommission
- Repo: `pos, store-wallet, bolt, yii-1.1.22`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
`yii-1.1.22` e ancora dipendenza runtime per tre applicazioni principali. Obiettivo di programma richiede eliminazione completa di Yii1 in produzione.

## Proposta
- Portare tutti i servizi utente su Yii2/PHP 8.3.
- Eseguire fase dual-run controllata (legacy + v2) solo per validazione.
- Terminare traffico su Yii1 e rimuovere componente dal runtime finale.

## Criteri di accettazione
- Nessuna app in produzione punta a `yii-1.1.22`.
- `yii-1.1.22` non compare in bootstrap runtime dei servizi attivi.
- Esiste piano rollback temporaneo documentato prima della rimozione definitiva.

## Impatto
- Deploy, operazioni, monitoraggio, gestione incident durante cutover.

## Note implementative
- Definire freeze window per switch finale.
- Eseguire test di carico e test regressione prima del decommission.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/pos/index.php`
- `/var/www/napay-project/store-wallet/index.php`
- `/var/www/napay-project/bolt/index.php`
- `/var/www/napay-project/yii-1.1.22/README.md`
