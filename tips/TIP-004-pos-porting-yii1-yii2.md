# TIP-004 - POS: porting da Yii1 a Yii2

- Stato: OPEN
- Area: POS
- Repo: `pos`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
`pos` avvia con bootstrap Yii1 (`index.php` -> `../yii-1.1.22/framework/yii.php`) e dipende da componenti legacy (`CActiveRecord`, `CController`, estensioni Yii1).

## Proposta
- Creare skeleton Yii2 dedicato POS.
- Migrare model/controller/view mantenendo parity funzionale:
  - gestione importi e incasso
  - lista transazioni BTC/TTS
  - stampa ricevute
  - pairing/sin e autenticazione collegata a Napay
- Migrare PWA/service-worker in asset pipeline compatibile Yii2.

## Criteri di accettazione
- Tutte le feature POS principali disponibili su nuovo codice Yii2.
- Nessuna dipendenza runtime da `yii-1.1.22`.
- Deploy POS su container PHP 8.3 riuscito.

## Impatto
- Repo `pos` completo (routing, auth, domain model, frontend PWA).

## Note implementative
- Pianificare mapping classi Yii1 -> Yii2 (`CActiveRecord` -> `yii\\db\\ActiveRecord`).
- Introdurre test smoke su flussi di pagamento e stampa.
- Integrare librerie condivise tramite pacchetti versionati, non path relativi.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/pos/index.php`
- `/var/www/napay-project/pos/protected/config/main.php`
