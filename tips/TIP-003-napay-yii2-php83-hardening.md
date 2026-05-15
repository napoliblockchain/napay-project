# TIP-003 - Napay Backoffice: hardening Yii2 su PHP 8.3

- Stato: OPEN
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
