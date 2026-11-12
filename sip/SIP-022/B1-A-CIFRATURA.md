# SIP-022 B1a - Busta credenziali, contratto e assegnazione

Master, 2026-11-12. Micro-step autorizzato a CLA dopo review B1; indipendente
dalla decisione sulla rotazione della chiave BTCPay e dal futuro schema DB.

## File e confini

Nuovo branch/worktree Napay da base master corrente, non il checkout principale.
Write set esclusivo: components/btcpay/provisioning/CredentialEnvelope.php,
tests/application/btcpay-credential-envelope.php e runner dedicato sotto
 tests/docker/btcpay-credential-envelope.sh. Documentazione di consegna in
sip/SIP-022/B1-A-HANDOFF.md nel worktree orchestratore. Non toccare altre classi,
config, composer, bootstrap, migration, controller o sorgenti master R3.

Helper puro: niente Yii, DB, file, env, rete, logging o generazione/persistenza
chiavi reali. Sodium gia disponibile nel runtime verificato dal master;
nessuna nuova dipendenza. Chiavi di test casuali solo in memoria/usa-e-getta.

## Contratto API

Tre operazioni statiche: encrypt(plaintext, context, kekVersion, kek),
decrypt(envelope, context, keyring), rewrap(envelope, context, keyring,
newKekVersion, newKek). Parametri segreti, keyring e busta con SensitiveParameter
per non inserirli nei trace. Errori sanitizzati senza valori, SQL o eccezione
originale contenente input. Non promettere cancellazione completa della memoria
PHP; DEK temporanee ripulite con sodium_memzero ove possibile.

Context richiede esattamente: account_id e merchant_id int positivi <=INT_MAX,
instance stringa digest hex64 minuscola, kind onboarding_password oppure api_key,
generation int positivo. Nessun campo derivato da email, nomi o payload liberi.
Canonicalizzare ordine e tipi prima di costruire AD. Il formato1 e la tabella
btcpay_merchant_credentials fanno parte dei dati associati.

Busta versione1: kek_version (ID ASCII1..64, allowlist lettere/cifre/_/-),
secret_nonce, ciphertext, dek_nonce, wrapped_dek. Campi binari in base64
standard canonica, decodifica stretta; reject campi ignoti/mancanti, tipi,
lunghezze e formati sconosciuti. Plaintext non vuoto, massimo16384 byte;
KEK e DEK esattamente32 byte, nonce24 byte, tag16 incluso nel ciphertext.
DEK e due nonce casuali nuovi a ogni encrypt, XChaCha20-Poly1305 IETF per
entrambi i livelli. Nessun riuso volontario di nonce/DEK tra buste.

AD del segreto lega formato/tabella/context; NON versione KEK. AD del wrapping
lega gli stessi dati piu versione KEK. Quindi rewrap cambia solo wrapping,
nonce wrapping e versione KEK: ciphertext e nonce del segreto invariati.
Un cambio account/merchant/istanza/tipo/generazione o versione senza rewrap
autorizzato deve fallire. keyring indicizzato per versione, nessun fallback
alla prima chiave se versione sconosciuta. Rewrap verifica autenticita prima
di restituire nuova busta; non restituisce plaintext al chiamante.

## Test e consegna

Round-trip dei due tipi, buste indipendenti per stesso segreto, binding di ogni
campo AD, tamper di ciphertext/nonce/DEK/versione, chiavi errate o mancanti,
base64 e lunghezze malformate, limiti di input, formato/attributi ignoti,
rewrap preserva payload e rifiuta vecchio keyring, errori/trace senza segreti.
Test e sintassi su PHP8.3.36; nessun accesso al DB o allo stack persistente.
Runner riusa immagine/runtime esistente senza nuove librerie; nessun test deve
stampare chiavi, password, buste complete o plaintext. Commit piccoli e handoff
con conteggi realmente eseguiti. Review master prima dell'integrazione.
