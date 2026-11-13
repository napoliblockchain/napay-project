# B1c - Coda worker: micro-step di codice approvato (2026-11-13)

Base: `feature/v2-btcpay-b1-integration`, B1b `7be3a3e0`.
Implementazione CLA su nuovo worktree/branch; nessuna nuova proposta richiesta.

## Perimetro

Componente dedicato in `components/btcpay/provisioning/ProvisioningJobs.php`
con Connection Yii iniettata, SQL parametrico, soli ID/stati/checkpoint.
Presa lavoro per istanza con transazione breve e FOR UPDATE SKIP LOCKED,
checkpoint prima della chiamata remota, aggiornamento esito CAS su ID,
owner, versione e lease non scaduta. Input identificativi/UUID/tipi/stati
validati; nessun token/password/API/KEK nel componente o nei log.

In-flight scaduto (anche marker presente con stato differente): solo
reconcile_required, mai ripresa automatica. Running scaduto senza checkpoint
puo essere ripreso da altro worker; vecchio owner non puo piu aggiornare.
Nessuna API generica che permetta in_flight -> retry automatico senza prova
dell'esito remoto. Non inglobare transazioni gia aperte dal chiamante.

Questo step riguarda la coda, NON la serializzazione completa della risorsa:
lock del mapping e controlli freschi di tenant/idoneita restano obbligatori
nel successivo orchestratore prima di qualsiasi chiamata esterna.
Niente HTTP, console daemon, backoff, nuovi GRANT/schema o hook nei controller.

## Test E Consegna

Nuovi `tests/application/btcpay-provisioning-jobs.php` e runner
`tests/docker/btcpay-provisioning-jobs.sh`, esclusivamente DB usa-e-getta.
Due connessioni reali: skip locked, doppia presa esclusa, istanze isolate,
esito tardivo respinto, checkpoint CAS, scadenza in volo non rilanciata,
riacquisizione senza checkpoint, input invalido e nessuna fuga di segreti.
Verificare anche con utente worker a privilegi limitati riusando matrice B1b.
Handoff breve con commit, test e limiti; bootstrap/stack restano master.
