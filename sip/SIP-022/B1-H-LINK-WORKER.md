# W3c - Executor Negozio E POS

Contratto master 2026-11-14, prima del codice. Solo stack usa-e-getta.

- Nuovo ProvisioningLinkWorker: runOnce(): bool, Jobs/Store e passi W2 gia
  approvati. Nessuna nuova persistenza, crittografia, HTTP o policy identita.
  Claim solo store_link/pos_link; CLI/Jobs sono riservati al master.
- Guardie fenced prima di mapping e rete, poi sull'esito: merchant attivo
  tramite AccountEligibility sulla stessa connessione, negozio del merchant,
  terminale del negozio e merchant. Mapping/esito nella stessa TX W3a;
  HTTP sempre fuori TX. Lock per instance+kind+entity attraverso HTTP.
- Account synced e chiave current necessari; per POS anche store_link synced.
  Dipendenza mancante: retry_wait senza HTTP, mapping esistenti restano pending.
  Non creare account o adottare settings/identificativi legacy.
- Nomi remoti iniziali generici con ID locale + marker: non estendere i GRANT
  per leggere dettagli negozio/terminale. Il merchant opera nella UI Napay.
- Prima di POST checkpoint create_store/create_pos_app atomico. Qualunque
  mapping reconcile_required o altro lavoro della stessa risorsa con marker
  in_flight comporta SOLO GET di riconciliazione, anche su nuova generazione.
  Uno solo marker esatto (POS anche PointOfSale) adotta; zero/multipli no POST.
- 429 usa RetryPolicy/remoteRejected quando prova mancata esecuzione; 401/403
  blocca link e mette account in revisione. Esito ignoto conserva checkpoint.
  Esito tardivo/non idoneo non adotta ID; preservare incertezza del POST,
  nessuna cancellazione automatica o nuovo marker.
- Prima versione non reclama automaticamente reconcile_required: relativa
  API coda/attivazione del ciclo seguono nel micro-step master W3d.
- Trace sanificate senza previous, tutte le dipendenze/callback sensibili.
  Nessun nuovo daemon, hook, migrazione, grant, accesso servizi condivisi.

Test DB worker ristretto + HTTP W2 simulato: happy path, dipendenze, scope
negativi, lease scaduta, disabilitazione/cambio scope durante rete, 429,
401/403, esito ignoto, nuova generazione dopo vecchio in_flight (zero POST),
marker zero/uno/multipli e tipo app errato. Nessun pagamento.
