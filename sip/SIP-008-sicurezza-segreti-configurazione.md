# SIP-008 - Sicurezza: secret management e configurazioni sensibili

- Stato: OPEN
- Area: Security
- Repo: `napay, pos, store-wallet, bolt`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Sono presenti configurazioni sensibili nel codice legacy (SMTP credentials e altri parametri). La nuova piattaforma richiede segregazione completa dei segreti e controlli standard di sicurezza runtime.

## Proposta
- Spostare tutti i segreti fuori repository (env file cifrati, vault, secret provider).
- Introdurre rotazione credenziali e policy minima privilegi.
- Uniformare logging security, rate limiting, CSRF/CORS/cookie policy.
- Introdurre scanning SAST e dependency audit in pipeline.

## Criteri di accettazione
- Nessun secret hardcoded in repository applicativi.
- Checklist security baseline superata per ogni repo.
- Pipeline blocca merge in presenza di secret leak o vulnerability critica.

## Impatto
- Config applicative, Docker secrets, pipeline CI, procedure operative.

## Note implementative
- Prima fase: censimento segreti e revoca credenziali esposte.
- Seconda fase: onboarding secret manager e policy rotate.

## Verifica repository
- Evidenze baseline:
- `/var/www/napay-project/store-wallet/protected/config/main.php`
- `/var/www/napay-project/bolt/protected/config/main.php`
- `/var/www/napay-project/napay/config/db.php`
