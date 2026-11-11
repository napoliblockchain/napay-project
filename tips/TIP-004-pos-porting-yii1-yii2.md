# TIP-004 - POS: porting da Yii1 a Yii2

- Stato: IN_PROGRESS
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

### Primo avvio Yii2 isolato (2026-11-11)

- Riviste modifiche dell'altro agente: Napay ora usa gateway condiviso, non le
  precedenti porte sandbox. Codice Napay e poawallet lasciati invariati.
- Il repo POS era ancora Yii1; creata base indipendente `pos/v2`, con proprio
  Composer lock, PHP 8.3.36 (annunci sicurezza php.net consultati), Yii2 2.0.55.
- `https://pos.localhost` sul Caddy condiviso, nuova sola rotta `conf.d/pos.caddy`.
  Nessuna nuova porta, nessuna modifica `/etc/hosts`; container POS su rete
  interna, rootfs read-only, nessun DB o accesso alle chiavi delle altre app.
- Riavvio gateway autorizzato esplicitamente dall'utente: validazione Caddy
  prima dell'operazione; POS, Napay e wallet rispondono 200 dopo il riavvio.
- Tastierino e validazione importi in anteprima; nessun pagamento, pairing,
  fattura, QR, storico o ricevuta attivi. Non e raggiunta parity funzionale.
- Vecchio `POSIdentity` autentica tramite SIN e ha controllo quote disabilitato:
  non portato automaticamente. Prossima fase: contratto API di provisioning e
  autenticazione terminali con l'agente responsabile del backend Napay.
- Avvio/stop POS separati: `bash pos/v2/docker/local.sh up|stop|status`.
  Nessun riavvio gateway automatico nel launcher. Nessun commit automatico.
- Test eseguiti: 18 importi, 9 configurazione, 24 HTTPS/browser, sintassi PHP/JS/shell, Compose,
  lock e audit Composer. Dettagli/limiti in `pos/v2/README.md`.

- Evidenze baseline:
- `/var/www/napay-project/pos/index.php`
- `/var/www/napay-project/pos/protected/config/main.php`
