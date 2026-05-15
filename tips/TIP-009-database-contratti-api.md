# TIP-009 - Database e contratti API tra applicazioni

- Stato: OPEN
- Area: Data / Integration
- Repo: `napay, pos, store-wallet, bolt`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-04-21

## Contesto
Le applicazioni condividono dominio dati e flussi operativi (merchant, POS, wallet, transazioni). La migrazione rischia regressioni se non vengono formalizzati schema, ownership dati e contratti API.

## Proposta
- Definire ownership tabelle e boundary per servizio.
- Introdurre specifica API versionata per integrazioni tra app.
- Pianificare migration DB con rollback e test dati reali anonimizzati.
- Definire idempotenza e tracciabilita per eventi critici (pagamento, sync, invio token).

## Criteri di accettazione
- Schema dati target documentato e versionato.
- Contratti API interni documentati (request/response/error codes).
- Test integrazione cross-app verdi in CI.

## Impatto
- Database MySQL, layer model/repository, controller API, job asincroni.

## Note implementative
- Evitare migration big bang non reversibili.
- Definire piani di reconciliation dati tra legacy e v2 nel periodo di coesistenza.

## Verifica repository
- Da completare durante analisi schema e API correnti.
