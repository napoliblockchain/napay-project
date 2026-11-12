# SIP-006 - Bolt: porting da Yii1 a Yii2

- Stato: REJECTED
- Area: Wallet Cittadino Legacy
- Repo: `bolt`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
`bolt` e wallet cittadino su Yii1 con login social, rubrica, invio token e sync blockchain.

## Proposta
Proposta originale (poi scartata): portare `bolt` direttamente a Yii2/PHP 8.3.

## Criteri di accettazione
- N/A (SIP rifiutata).

## Impatto
- Nessuna implementazione diretta pianificata su `bolt`.

## Note implementative
Motivo rifiuto:
- Scelta architetturale approvata in SIP-013: base wallet `poawallet`.
- `bolt` resta solo sorgente storica/riferimento.
- `bolt` entra in policy archive (SIP-015), senza sviluppo feature nuove.

## Verifica repository
- `/var/www/napay-project/bolt/index.php`
- `/var/www/napay-project/sip/SIP-013-selezione-base-wallet-eth-poa.md`
