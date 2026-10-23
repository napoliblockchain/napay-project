# TIP-003 - Napay Backoffice: hardening Yii2 su PHP 8.3

- Stato: IN_PROGRESS
- Area: Backoffice
- Repo: `napay`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
`napay` usa Yii2 ma baseline attuale e `php >=7.4` in `composer.json`, mentre Dockerfile usa `php:8.2-apache`. Obiettivo target richiede PHP 8.3 e standard runtime comune con gli altri servizi.

## Proposta
- Portare vincolo `composer` a PHP 8.3.
- Allineare Dockerfile a `php:8.3-*` e razionalizzare estensioni.
- Verificare compatibilita dipendenze Yii2/Kartik/AdminLTE su 8.3.
- Standardizzare gestione config (`secrets.php` o env provider) e bootstrap.

## Criteri di accettazione
- `composer install` e test principali passano con PHP 8.3.
- Container `napay` avvia senza warning deprecati bloccanti.
- Nessuna regressione funzionale su login, merchant, pos management, invoice, API v1.

## Impatto
- Repo `napay` (config, composer, docker, pipeline).

## Note implementative
- Conservare compatibilita con bootstrap5 e moduli Gii/Debug in dev.
- Separare strict mode runtime prod da debug dev.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/napay/composer.json`
- `/var/www/napay-project/napay/docker/Dockerfile`
- `/var/www/napay-project/napay/docker-compose.yml`

## Log esecuzione

### Pin PHP 8.3.36 (2026-10-23)
- `docker/Dockerfile`: `php:8.2-apache` → `php:8.3.36-apache`.
- `docker/Dockerfile_Image`: `VARIANT` di default `8.2` → `8.3.36`.
- `composer.json`: requisito PHP `>=7.4.0` → `>=8.3`.
- Verifiche su `php:8.3.36-cli`: lint 162 file OK; build layer di sistema ed estensioni OK; risoluzione dipendenze runtime OK (yii2 2.0.55, mpdf 8.3.1, phpspreadsheet 1.30.7).
- Aperto: `composer.lock` escluso da `.gitignore` (build non riproducibili); `require-dev` non risolvibile (`phpunit ~9.5.0` bloccato da security advisory); Dockerfile installa tool non necessari (htop, nano, certbot, nvm); credenziali MySQL passate come build arg e salvate nei layer dell'immagine (vedi TIP-008).
