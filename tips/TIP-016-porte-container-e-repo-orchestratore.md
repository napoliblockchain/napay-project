# TIP-016 - Piano porte container e repo orchestratore unico

- Stato: IN_PROGRESS
- Area: Platform Governance / DevOps
- Repo: `napay-project`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Stack attuale usa porte standard o sovrapposte (80, 443, 3306, 9001, 8180, 8181). Rischio alto conflitti tra ambienti locali e servizi multipli wallet/backoffice.

In parallelo serve decidere modello repository: multi-repo puro o repo orchestratore unico per piattaforma Docker.

## Proposta
1. Definire matrice porte host non standard centralizzata in `napay-project/.env.example`.
2. Esporre su host solo ingress gateway e tool operativi; tenere servizi applicativi e database su rete Docker privata.
3. Usare `napay-project` come repo orchestratore unico (compose, env, script, docs, CI di integrazione), mantenendo codice applicativo nei repo dedicati.

## Criteri di accettazione
- Esiste compose orchestratore unico (`docker-compose.yml` + `include` per area) con porte parametrizzate e non standard.
- Esiste `.env.example` centrale con valori porta allineati.
- `tips/README.md` include TIP-016 in indice.
- Policy repo definita: orchestrazione centralizzata in `napay-project`, sviluppo applicativo nei singoli repo.

## Impatto
- `napay-project/docker-compose.yml` + `docker/compose/{infra,wallet,napay}.yml`
- `napay-project/docker/gateway/conf.d/{napay,wallet}.caddy`
- `napay-project/docker/gateway/Caddyfile`
- `napay-project/.env.example`
- `napay-project/tips/README.md`
- Gestione container futuri `napay`, `poawallet`, `pos`, `store-wallet`, `tokenpay` (staging source)

## Note implementative
- Porte host proposte (non standard):
  - `18080` gateway HTTP
  - `18443` gateway HTTPS
  - `13306` mysql
  - `16379` redis
  - `18081` adminer
  - `18025` mailhog ui
  - `11025` mailhog smtp
  - `19090` prometheus
  - `13000` grafana
  - `18110` websocket notifiche
- Servizi app web non pubblicano porte host; accesso via reverse proxy interno.
- `tokenpay` resta repo sorgente merge (staging source), non target di nuove feature autonome.

## Log esecuzione

### Step 2.1 - Baseline porte + gateway reverse proxy (COMPLETED, 2026-04-21)
- Creato compose orchestratore root:
  - `docker-compose.base.yml`
- Creato env centrale porte:
  - `.env.example`
- Creata configurazione gateway reverse proxy:
  - routing `napay.local` -> `napay-web:80`
  - routing `wallet.local` / `poawallet.local` -> `wallet-web:80`
- Routing definito:
  - `napay.local` -> `napay-web:80`
  - `wallet.local` / `poawallet.local` -> `wallet-web:80`
  - default -> `napay-web:80`
- Verifica eseguita:
  - `docker compose -f docker-compose.base.yml config` = OK

### Step 2.2 - HTTPS gateway e certificati (COMPLETED, 2026-04-21)
- Definita policy HTTPS:
  - redirect HTTP -> HTTPS per host wallet/backoffice
  - listener TLS su `443` interno container (esposto host su `18443`)
  - routing TLS:
    - `napay.local` / `napay.test` / `localhost` -> `napay-web:80`
    - `wallet.local` / `poawallet.local` / `wallet.test` -> `wallet-web:80`

### Step 2.3 - Migrazione Caddy auto-TLS (COMPLETED, 2026-04-21)
- Sostituito gateway con `caddy:2.8.4-alpine`.
- Rimossa gestione cert manuale da repository.
- Configurato `local_certs` su Caddy:
  - certificati locali gestiti automaticamente da Caddy
  - nessun `crt/key` versionato o script openssl richiesto
- Nuova configurazione:
  - `docker/gateway/Caddyfile`
- Verifica eseguita:
  - `docker compose -f docker-compose.base.yml config` = OK

### Step 2.4 - Cert management stage/prod (OPEN)
- Configurare issuer stage/prod (ACME pubblico o PKI aziendale).
- Automatizzare rotazione cert in pipeline deploy.

### Step 2.5 - Compose e gateway separati per area (COMPLETED, 2026-10-23)
- Motivo: un solo file compose/Caddyfile modificato da piu agenti (napay, wallet) in parallelo.
- `docker-compose.base.yml` sostituito da `docker-compose.yml` con `include` (Compose >= 2.20), `project_directory: .` (percorsi e `.env` dalla root):
  - `docker/compose/infra.yml`: gateway, mysql, redis, adminer, mailhog, prometheus, grafana, rete e volumi
  - `docker/compose/wallet.yml`: wallet-web, ws-notify, tokenpay-staging
  - `docker/compose/napay.yml`: napay-web, pos-web, store-wallet-web
- `Caddyfile`: opzioni globali e default `:80`; siti in `conf.d/napay.caddy` e `conf.d/wallet.caddy` (`import conf.d/*.caddy`).
- `wallet-web`: `env_file: ./poawallet/.env` (`required: false`); `environment` dell'orchestratore ha la precedenza (DB).
- `wallet-web`: `build` da `./poawallet` target `dev` (`docker compose build wallet-web`); immagini di rilascio con `docker build --target prod`.
- Regola: ogni agente/app modifica solo il proprio file in `docker/compose/` e `conf.d/`; `infra.yml` e `Caddyfile` solo con accordo.
- Avvio: `docker compose up -d` (non serve piu `-f docker-compose.base.yml`).
- Verifica: `docker compose config` (tutti i profili) identico al precedente salvo il mount `conf.d`; `caddy adapt` JSON identico; `caddy validate` OK.

## Verifica repository
- `/var/www/blockchain-napoli/napay-project/docker-compose.yml`
- `/var/www/blockchain-napoli/napay-project/docker/compose/`
- `/var/www/napay-project/docker/gateway/Caddyfile`
- `/var/www/napay-project/.env.example`
- `/var/www/napay-project/tips/README.md`
