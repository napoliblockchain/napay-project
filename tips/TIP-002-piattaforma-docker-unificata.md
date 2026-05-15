# TIP-002 - Piattaforma Docker unificata

- Stato: OPEN
- Area: DevOps / Runtime
- Repo: `napay, pos, store-wallet, bolt`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Al momento solo `napay` ha una base Docker (`docker-compose.yml`, Dockerfile con `php:8.2-apache`). Gli altri repo principali non hanno stack container standardizzato.

## Proposta
Creare piattaforma Docker comune con:
- immagini applicative per ogni repo su PHP 8.3
- `compose` per ambienti `dev`, `staging`, `prod`
- servizi condivisi: `mysql`, `redis`, `queue-worker`, `scheduler`, `reverse-proxy`
- healthcheck, logging strutturato, rete privata tra servizi

## Criteri di accettazione
- Ogni repo ha `Dockerfile` PHP 8.3 e `.dockerignore` coerente.
- Esiste `compose` root di orchestrazione multi-app.
- Tutti i servizi rispondono a healthcheck e possono fare boot con un solo comando.

## Impatto
- Runtime applicativo e modalita deploy.
- Config ambienti e processo locale di sviluppo/test.

## Note implementative
- Evitare installazioni runtime superflue nel container (es. tool desktop).
- Separare immagini build-time da immagini run-time.
- Introdurre volumi e secret mount invece di file sensibili nel repo.

## Verifica repository
- Da completare durante implementazione.
