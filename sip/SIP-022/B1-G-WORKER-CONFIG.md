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

## Primo Comando One-Shot

Prossimo codice master: entrypoint `php yii-btcpay btcpay-provision/run --once`
con allowlist esatta della rotta/opzione, configurazione isolata, errori fissi
senza trace. Controller costruisce i componenti gia approvati, verifica
readiness ristretta prima di processare il lavoro, senza migrazioni o fallback.
Solo account merchant W3b: nessun daemon o flusso store/POS dichiarato pronto.
Esito pubblico soltanto `idle`/`job-processed`, non equivale a pagamento pronto.
File specificati tramite BTCPAY_PROVISIONER_KEY_FILE/BTCPAY_KEK_KEYRING_FILE,
origine BTCPAY_PROVISION_ORIGIN, CA facoltativa BTCPAY_PROVISION_CA_FILE;
PAYMENT_PROXY obbligatorio, sempre trasporto esistente con TLS verificato.

## CLI Verificata

2026-11-14: codice `a9443f0d`, test `1dbd63ce` nel branch master isolato.
**14 PASS** su MySQL/overlay ruoli reali: idle, job inesistente fallito senza
mapping, comandi estranei/daemon vietati, secret mancanti, proxy assente,
origine HTTP, credenziali errate, migrator con password valida ma privilegi
troppo ampi. Errori fissi anche su file bootstrap mancanti; nessuna trace,
valore segreto, chiave web o migrazione. Console limitata anche dall'ID/ruolo
del bootstrap dedicato. Config/loader39 test riconfermati.
Nessuna chiamata BTCPay reale: non certifica ancora onboarding regtest completo
o servizio continuo. Nessuna modifica allo stack condiviso.
