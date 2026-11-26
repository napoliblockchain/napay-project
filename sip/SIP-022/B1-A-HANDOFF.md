# SIP-022 B1a - Handoff agente Napay (CLA)

## Workspace

- Worktree Napay: `/var/www/blockchain-napoli/napay-worktrees/napay-btcpay-b1a`.
- Branch: `feature/v2-btcpay-b1a-envelope`, base `e5f5d86e`
  (`feature/v2-yii2-php83-docker` al momento della creazione).
- Write set (contratto `B1-A-CIFRATURA.md`), nessun altro file toccato:
  - `components/btcpay/provisioning/CredentialEnvelope.php`
  - `tests/application/btcpay-credential-envelope.php`
  - `tests/docker/btcpay-credential-envelope.sh`

## Commit

- `16e11c8c` feat: helper `CredentialEnvelope`.
- `1b6754e8` test: 59 controlli e runner dedicato.

- Correzioni della [review master](B1-A-REVIEW-MASTER.md):
  - `dfeffa99` fix: RV1 `SensitiveParameter` anche sui parametri privati
    (`unwrap` con le parti decodificate, costruzione della busta); RV2 tipo e
    lunghezza codificata massima controllati prima di `base64_decode`;
  - `a87b0164` test: visita ricorsiva degli argomenti di tutti i frame (salta
    solo `SensitiveParameterValue`) cercando anche le parti binarie in 5 casi
    d'errore; campo di 8 MiB rifiutato con picco di memoria < 1 MiB; lunghezza
    appena oltre il limite rifiutata. **67 PASS.** Discriminazione: fallisce
    sul componente precedente (RV1) e senza il controllo di lunghezza (RV2).
  - Formato, primitive, API, contesto e write set invariati. Il tipo
    `onboarding_password` resta compatibile con la decisione B (identificatore
    stabile, non più segreto temporaneo).

## Implementazione rispetto al contratto

- `encrypt(plaintext, context, kekVersion, kek)`, `decrypt(envelope, context,
  keyring)`, `rewrap(envelope, context, keyring, newKekVersion, newKek)`,
  statiche, senza Yii/DB/file/ambiente/rete/log.
- Contesto: esattamente `account_id`, `merchant_id`, `instance`, `kind`,
  `generation`; interi stretti 1..2147483647, `instance` hex64 minuscolo,
  `kind` `onboarding_password` o `api_key`; ordine canonico.
- Dati associati del segreto:
  `napay-btcpay-credential|format=1|table=btcpay_merchant_credentials|account_id=…|merchant_id=…|instance=…|kind=…|generation=…`;
  del wrapping: gli stessi più `|kek_version=…`.
- Busta: `version` (intero 1), `kek_version` (`^[A-Za-z0-9_-]{1,64}$`),
  `secret_nonce`, `ciphertext`, `dek_nonce`, `wrapped_dek` in base64 standard
  canonica (decodifica stretta e ricodifica identica); nonce 24, wrapped DEK
  48, ciphertext 17..16400 byte; campi ignoti o mancanti rifiutati.
- Plaintext 1..16384 byte; KEK 32 byte; DEK e due nonce nuovi a ogni encrypt.
- Keyring indicizzato per versione, nessun ripiego.
- `rewrap`: decifra DEK e segreto (autenticità), azzera il segreto, nuovo
  nonce di wrapping; ciphertext e nonce del segreto invariati; non
  restituisce il plaintext.
- Errori: `InvalidArgumentException` (`invalid_context`, `invalid_envelope`,
  `invalid_key`, `invalid_kek_version`, `invalid_plaintext`,
  `unknown_kek_version`) o `UnexpectedValueException` (`decryption_failed`,
  `crypto_error`); mai eccezione precedente né valori nel messaggio.
- `#[\SensitiveParameter]` su plaintext, KEK, keyring e busta; DEK azzerate con
  `sodium_memzero`. Non si promette cancellazione completa della memoria PHP
  (il plaintext restituito da `decrypt` resta al chiamante).

## Test

`sh tests/docker/btcpay-credential-envelope.sh` (immagine `napay/napay:dev`,
PHP 8.3.36 con sodium, `--network none`, filesystem in sola lettura):
**67 PASS** (59 iniziali + 8 della review), lint del componente ok.

- Round trip per entrambi i tipi; forma e lunghezze; due buste dello stesso
  segreto indipendenti; 16384 byte accettati.
- Legame di ciascun campo del contesto e della versione KEK (stessa chiave
  sotto un'altra versione rifiutata).
- Manomissione di ciphertext, nonce, nonce DEK, wrapped DEK; KEK errata,
  corta, versione assente, keyring vuoto.
- 14 buste malformate (campi, tipi, versione, base64 non canonica, url-safe,
  spazi, lunghezze), 9 contesti non validi, ordine dei campi irrilevante.
- Rewrap: invarianti, nuovo keyring, rifiuto del vecchio, verifica
  dell'autenticità prima del nuovo wrapping, legame al contesto.
- Trace con `zend.exception_ignore_args=0`: nessun segreto, chiave o valore
  della busta in messaggio, stringa e `print_r` della trace. Prova di
  discriminazione: con una copia del componente senza `SensitiveParameter`
  chiave e busta compaiono nella trace.
- Nota sul test: la prima versione ispezionava trace generate dentro le
  closure del test, che catturano chiavi e busta; corretto con try/catch
  diretti, così si verifica solo ciò che espone il componente.

Non eseguiti/fuori perimetro: DB, schema, worker, gestione della KEK reale,
rotazione della chiave merchant (decisione dell'utente).

## Integrazione

Review del master prima di qualunque cherry-pick; nessun file condiviso o
del master modificato; nessun DB, stack, segreto o rete usati.
