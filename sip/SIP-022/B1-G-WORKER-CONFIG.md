# Worker - Configurazione Isolata

Contratto master 2026-11-13, prima del codice. Nessun deploy in questo step.

- Console dedicata `config/btcpay-worker.php`, senza params applicativi,
  mailer, sessione, SECRET_HASH_KEY o COOKIE_VALIDATION_KEY. Solo DB worker,
  cache/log privati e logVars vuoto; nessun bootstrap/migration automatico.
- Richiede ruolo worker, separazione attiva, debug disattivo, env esterno
  e secret DB esattamente `/run/secrets/napay_db_worker_password`.
  Rifiuta password DB raw all'ingresso e variabili/secret root, migrator,
  web o chiavi applicative. Riusa config/env.php e config/db.php.
- Loader nuovo `components/btcpay/provisioning/WorkerSecrets.php`: sola
  lettura di file regolari non symlink sotto /run/secrets, permessi solo
  proprietario. Provisioner: riusa DatabaseSecret, ulteriore controllo
  ASCII stampabile compatibile con il client HTTP gia approvato.
- Keyring JSON, massimo8KiB: `current` (versione KEK), `keys` (mappa di
  1..16 versioni a chiavi32byte codificate base64 standard canonica).
  Versioni secondo CredentialEnvelope, current deve esistere. Niente
  nuova crittografia, generazione, scrittura o rotazione implicita.
- Oggetto loader conserva i segreti avvolti in SensitiveParameterValue;
  getter espliciti per Store/HTTP. Errori fissi senza catena di eccezioni
  o dati remoti/file nei log; parametri sensibili lungo tutti i passaggi.
- Origin/CA/proxy validati dal client HTTP esistente alla costruzione,
  instance derivata dall'origine configurata. Config/loader non chiamano
  reti, non accodano lavori e non avviano worker. CLI/compose dopo executor.

Test senza rete con input temporanei 0700/0600: casi validi, file mancanti,
pubblici, symlink/path traversal, JSON/base64/versioni malformati o grandi,
dump/trace privi di chiavi, configurazione senza chiavi web e rifiuto di
scope privilegiati/debug/raw password. Nessun segreto reale nei test.

## Implementazione Verificata

Napay `a0a1c895` codice, `a7d95986` test nel branch isolato master.
**39 PASS**, lint PHP/shell e diff verificati. La console minima viene
istanziata senza chiavi web o amministratore; nessuna connessione DB/rete.
Coperti anche keyring multiversione, dump e trace senza segreti, secret
root/migrator montati per errore e APP_DEBUG=true con Yii gia caricato.
CLI/compose e prova con executor restano allo step successivo; nessun deploy.
