# B1c - Review master (2026-11-13)

Consegna f447733a/00b0d2c8. Due finding corretti da CLA:
- RV1: deferred non puo essere preso automaticamente, anche gia dovuto.
- RV2: marker pending/retry_wait con lease valida non va riconciliato finche
  il worker e attivo; dopo scadenza solo reconcile, mai nuova presa.

Fix fcf2fd5f/0ff5fbf0 approvati dopo mio runner: **63 PASS**, due connessioni
worker limitate, gare, lease, CAS e bootstrap no-op. Integrati sul branch
isolato feature/v2-btcpay-b1-integration come8b50d448/12f87fbb/e6928322/
2c7f116a. Nessun daemon, lock mapping, HTTP o provisioning reale in B1c.
