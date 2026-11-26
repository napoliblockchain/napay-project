# SIP-013 - Scelta base wallet ETH/POA tra Bolt, Poawallet e Tokenpay

- Stato: COMPLETED
- Area: Wallet Architecture
- Repo: `bolt, poawallet, tokenpay`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Sono presenti tre repository wallet con genealogia evolutiva:
- `bolt` -> legacy Yii1
- `poawallet` -> evoluzione Yii2 orientata wallet operativo
- `tokenpay` -> evoluzione successiva con pannelli admin/network piu estesi

Serve scegliere una sola base per accelerare wallet ETH/POA ready.

## Proposta
Usare `poawallet` come base principale, con integrazione selettiva di moduli utili da `tokenpay`.

## Criteri di accettazione
- Esiste motivazione tecnica verificabile per la base scelta.
- La base scelta ha send/receive/wallet flow funzionanti lato MVC e UI.
- Esiste piano successivo per assorbire moduli utili del repo non scelto.

## Impatto
- Roadmap wallet v2.
- Priorita refactoring e migrazione codice.

## Note implementative
Esito confronto tecnico:
- `bolt` escluso: runtime Yii1 (`index.php` carica `yii-1.1.22`).
- `poawallet` promosso: ha `SendController` con `actionGenerateTransaction` e `actionValidateTransaction`, viste send, wiring JS/route completo.
- `tokenpay` non scelto come base: menu e wallet linkano `send/index`, ma manca `SendController`; il motore `Erc20::sendToken()` esiste, ma wiring MVC non chiuso.

## Verifica repository
- `/var/www/napay-project/bolt/index.php`
- `/var/www/napay-project/poawallet/controllers/SendController.php`
- `/var/www/napay-project/poawallet/views/send/send_js.php`
- `/var/www/napay-project/tokenpay/themes/adminlte/wallets/view.php`
- `/var/www/napay-project/tokenpay/themes/adminlte/layouts/main-sidebar.php`
- `/var/www/napay-project/tokenpay/components/Erc20.php`
