# SIP-005 - Store Wallet: porting da Yii1 a Yii2

- Stato: OPEN
- Area: Wallet Merchant
- Repo: `store-wallet`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
`store-wallet` e Yii1 con integrazione blockchain e componenti security legacy. Config attuale include elementi sensibili nel codice e dipendenze esterne via `../../../packages`.

## Proposta
- Porting completo a Yii2/PHP 8.3.
- Separare core wallet logic da layer web.
- Migrare sync blockchain, invio token, gestione seed, 2FA.
- Introdurre service worker e code path offline in struttura frontend moderna.

## Criteri di accettazione
- Flussi wallet merchant operativi su Yii2:
  - login + eventuale 2FA
  - visualizzazione saldi/token
  - invio e ricezione token
  - sync transazioni
- Eliminati include legacy legati a Yii1.
- Deploy containerizzato in stack Docker v2.

## Impatto
- Repo `store-wallet` completo.
- Contratti di integrazione con `napay` e servizi blockchain.

## Note implementative
- Priorita alta su data migration e sicurezza chiavi private.
- Ridurre JS inline in view e spostare logica in moduli frontend testabili.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/store-wallet/index.php`
- `/var/www/napay-project/store-wallet/protected/config/main.php`
