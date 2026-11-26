# W3e - Riconciliazione GET-Only Dei Link E Routing CLI

Contratto 2026-11-14 (CLA master ad interim), prima del codice. Nessun daemon,
deploy, migrazione o GRANT nuovo. Solo stack usa-e-getta.

## Riconciliazione nell'executor link

- Nuovo `ProvisioningLinkWorker::reconcileOnce(): bool`, separato da `runOnce()`.
  Usa solo le API W3d: `claimReconciliation` (store_link/pos_link),
  `prepareReconciliation`, `succeed` con callback, `retryReconciliation`.
- Stesso lock di risorsa di `runOnce()` (istanza+tipo+entita) durante l'HTTP;
  risorsa occupata: `retryReconciliation` breve, nessuna chiamata.
- Preparazione fenced: scope come in W3c (merchant idoneo, negozio, terminale
  e relativo merchant) prima di leggere mapping e chiave. Il mapping deve gia
  esistere: la riconciliazione non crea mai mapping, account o marker.
- Solo GET (`StoreLinkStep::reconcile` / `PosLinkStep::reconcile`), mai POST,
  qualunque sia l'esito.
- Esiti:
  - marker unico (POS: solo PointOfSale): `succeed` con callback che adotta
    l'ID dopo il ricontrollo di scope, nella stessa transazione;
  - 429 o lettura non disponibile: `retryReconciliation` con RetryPolicy
    (deferred oltre la soglia della policy);
  - marker assente: nuova GET piu tardi con RetryPolicy (incertezza conservata);
  - marker multiplo, link gia failed/suspended, mapping mancante: deferred
    (decide l'admin), marker conservato;
  - 401/403: link failed, account in revisione, lavoro deferred;
  - dipendenza non pronta: nuova GET piu tardi;
  - merchant o scope non piu validi (alla preparazione o all'esito): nessuna
    adozione, deferred `merchant_ineligible` / `scope_mismatch`.
- Esito tardivo con lease scaduta: nessun effetto (CAS W3a).

## Routing CLI

- `yii-btcpay` accetta solo tre comandi one-shot, sempre con `--once`:
  `btcpay-provision/run` (account, invariato), `btcpay-provision/links`
  (un lavoro link), `btcpay-provision/reconcile` (una riconciliazione link).
  Qualunque altro argomento: usage, nessun bootstrap.
- Stessa configurazione dedicata, readiness ristretta e segreti del worker;
  `links` e `reconcile` non leggono la chiave del provisioner.
- Output solo `idle` / `job-processed`; errori generici senza trace.

## Test

Worker DB ristretto + HTTP W2 simulato: adozione marker unico store e POS,
tipo app errato ignorato, zero marker con nuova attesa, marker multipli
deferred, 429 con Retry-After, 401/403, dipendenza mancante, merchant
disabilitato prima e durante la GET, lease scaduta, risorsa occupata, mai POST,
mapping mancante. CLI: i tre comandi raggiungono `idle` con grant reali, comandi
estranei rifiutati prima del bootstrap. Regressioni: link, worker, coda,
fencing, riconciliazione, CLI.

## Esito (2026-11-14)

Integrato con fast-forward in `feature/v2-btcpay-b1-integration` (HEAD
`814e515c`): `be001143` reconcileOnce, `b3207946` WorkerSecrets::keyringOnly,
`2dabae89` CLI links/reconcile, `e970be6b` e `814e515c` test. Verdi: link 57
(di cui 20 W3e), CLI 17, config/segreti 41, worker account 37, coda 63,
fencing 18, riconciliazione 27. Review non indipendente (stesso autore).
Nessun daemon, cron o deploy: i tre comandi restano one-shot manuali.
