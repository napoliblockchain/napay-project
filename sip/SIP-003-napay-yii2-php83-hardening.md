# SIP-003 - Napay Backoffice: hardening Yii2 su PHP 8.3

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
- Aperto: `composer.lock` escluso da `.gitignore` (build non riproducibili); `require-dev` non risolvibile (`phpunit ~9.5.0` bloccato da security advisory); Dockerfile installa tool non necessari (htop, nano, certbot, nvm); credenziali MySQL passate come build arg e salvate nei layer dell'immagine (vedi SIP-008).

### Configurazione solo `.env` e build senza credenziali (2026-10-23)

- Runtime fissato a PHP `8.3.36`, come gia impostato; requisito minimo Composer
  aggiornato a `>=8.3.36`. Nessuna attestazione di assenza CVE basata sul solo pin.
- `config/env.php` riprende il pattern Aura: `.env` locale, precedenza variabili
  del processo, booleani e ambiente validati, default produzione/debug disattivo.
- `config/db.php`, `params.php`, `web.php`, entrypoint web e console migrati:
  nessun caricamento `secrets.php`. DB, cookie e chiave cifratura obbligatori;
  nessuna generazione automatica o fallback a valori fittizi.
- `.env.example` e `docker/README.md` descrivono tutte le variabili e il mapping
  legacy. Chiavi crittografiche esistenti da preservare durante la migrazione.
- Rimossi ARG/ENV con credenziali dai due Dockerfile e generazione VAPID in build.
  `.dockerignore` esclude file sensibili dal contesto; `docker/db-docker.php`
  delega alla configurazione unica.
- Compose locale legge `.env` solo a runtime; porta diagnostica `127.0.0.1:18120`,
  nessun binding 80/443 sull'host. TLS resta responsabilita del gateway Caddy.
- Test configurazione isolati in `napay/tests/config/environment.php`.
- Aperto: configurare ambiente operativo, wiring env del servizio `napay-web`
  nell'orchestratore condiviso e smoke login/API con DB di test. Dipendenze vendor
  incomplete e assenza di lock impediscono ancora di dichiarare l'app pronta.
- Nuova [SIP-018: migrazione Tabler](SIP-018-napay-migrazione-tabler.md), basata sul
  lavoro Aura. Solo proposta tecnica; implementazione UI non iniziata.

Verifiche eseguite sull'intervento `.env`: 23 controlli configurazione isolati
con immagine `php:8.3.36-apache`, lint dei file PHP coinvolti e validazione del
compose locale con configurazione fittizia. Nessun test funzionale login,
merchant, invoice o API eseguito: vendor applicativo incompleto e ambiente DB
operativo non configurato. Nessuna build completa dell'immagine eseguita in
questo intervento; le dipendenze e la supply chain rimangono da verificare.
