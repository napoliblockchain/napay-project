# SIP-001 - Inventario software e perimetro tecnico Napay

- Stato: COMPLETED
- Area: Architettura
- Repo: `napay, pos, store-wallet, bolt, poawallet, tokenpay, packages, docs, ttstoken`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
La piattaforma Napay e distribuita su piu repository e stack misti (Yii1 e Yii2). Senza inventario tecnico unico non e possibile pianificare migrazione coerente a Docker full-stack e PHP 8.3.

## Proposta
Definire baseline tecnica unica con:
- elenco software e ruoli
- stack runtime corrente per ciascun repo
- branch target v2 per sviluppo parallelo
- criticita tecniche da risolvere prima del cutover

## Criteri di accettazione
- Esiste mappa completa software in `sip/README.md` con stato e area di ogni SIP.
- Ogni repo principale ha branch target v2 assegnato.
- Sono elencati i punti legacy chiave (Yii1, secrets hardcoded, dipendenze datate, divergenza wallet).

## Impatto
- Tutti i repository del perimetro Napay.
- Pianificazione tecnica e governance del programma di migrazione.

## Note implementative
- `napay`, `poawallet`, `tokenpay` sono Yii2 ma con baseline dipendenze datate.
- `pos`, `store-wallet`, `bolt` sono Yii1 bootstrap su `yii-1.1.22`.
- `tokenpay` non ha send flow MVC completo (link a `send/index` senza `SendController`).
- `packages` usa submodule multipli con dipendenze eterogenee.
- `ttstoken` e il token ERC20 (TTS) deployato sulla blockchain POA Hyperledger Besu (chainId 2118). Non e un'app Yii ma un contratto Solidity/Vyper gestito con Truffle. Installato su VPS separata. Vedi SIP-017.

## Verifica repository
- `/var/www/napay-project/napay/composer.json`
- `/var/www/napay-project/poawallet/composer.json`
- `/var/www/napay-project/tokenpay/composer.json`
- `/var/www/napay-project/pos/index.php`
- `/var/www/napay-project/store-wallet/index.php`
- `/var/www/napay-project/bolt/index.php`
- `/var/www/napay-project/packages/.gitmodules`
- `https://github.com/napoliblockchain/ttstoken.git` (external, VPS blockchain)
