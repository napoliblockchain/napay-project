# SIP-038 - Implementazione per micro-step

## A - Cifratura offline (in corso, 2026-11-26)

Riutilizzare GnuPG, gia usato per il backup manuale chain, ma con destinatario
asimmetrico: sul server solo chiave pubblica e fingerprint intera attesa.
Script interno eseguibile nel futuro container strumenti; nel primo collaudo
si usa GnuPG locale con chiavi usa-e-getta, senza installazioni sull'host.
Nessuna nuova dipendenza richiesta alle VPS in questo passo.

Ingressi: chiave pubblica, fingerprint, backup locale completo, directory
privata di uscita. Percorsi assoluti canonici, fuori dal repository; proprietario
corrente e permessi privati per dati/uscita; niente symlink o file speciali.
Rifiutare chiavi private, bundle con piu chiavi primarie, fingerprint errata,
file vuoto o destinazione gia presente. Keyring temporaneo separato dal profilo
utente. Nessuna ricerca di chiavi in rete. Pubblicare il file cifrato solo a
completamento, senza sovrascrivere. Backup originale sempre conservato.

Prove: decifratura in keyring separato con confronto byte per byte; keyring
con sola chiave pubblica non decifra; manomissione rifiutata; casi negativi
percorsi/permessi/chiavi e assenza di output completo su errore.
Questo NON e una prova di ripristino MySQL o di upload S3.

## B - Trasporto S3 e contenitore strumenti

Scegliere/verificare client e immagine versionata, fornire controlli preliminari
senza rete e upload dei soli cifrati. Config da file privato; HTTPS verificato,
nessun secret in argomenti/log, retry limitati, nessun delete remoto.
Bucket, endpoint e permessi effettivi da confermare prima di chiamate reali.
Retenzione remota non implementata senza decisione utente.

## C - Collegamento backup e timer

Riutilizzare backup-daily.sh: dump locali restano validi se upload fallisce,
ma il servizio segnala errore. Lock e idempotenza per evitare sovrapposizioni.
Backup coerente della chain/chiavi in passo dedicato; mai tar live del DB Besu
senza procedura consistente e finestra autorizzata.

## D - Ripristino e attivazione

Download da S3, decifratura con chiave custodita fuori VPS, ripristino MySQL e
chain su risorse usa-e-getta e confronto dati. Poi guida di attivazione, solo
con autorizzazione utente; nessun deploy incluso nel codice.

Fonti GnuPG:
- https://www.gnupg.org/documentation/manuals/gnupg/GPG-Input-and-Output.html
- https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html

## Esito A (2026-11-26)

Implementati docker/backup-offsite/encrypt.sh e tests/backup-offsite.sh.
Eseguiti 19 controlli offline: recupero identico byte per byte, file 0600,
chiave pubblica incapace di decifrare, rifiuto sovrascrittura e corruzione,
fingerprint corta/errata, chiave privata, backup leggibile da altri,
directory pubblica, symlink diretto/antenato, path relativo, backup vuoto o
parziale, chiave malformata, bundle multiplo, errore GPG simulato e concorrenza.
Chiavi/dati esclusivamente usa-e-getta; nessuna chiamata di rete o DB.
Lint bash superato. ShellCheck non disponibile nell'ambiente locale.

La verifica di integrita OpenPGP non e una firma del produttore. Non pubblicare
plaintext di un recupero prima del successo finale GPG. Questi controlli non
provano disponibilita S3, ripristino MySQL/Besu o robustezza del futuro container.
Nessun timer, dato utente, backup reale o stack condiviso modificato.

## Contratto B - contenitore e invio (2026-11-26)

Client scelto: rclone ufficiale 1.76.0, digest fissato; base Alpine 3.23 con
digest fissato. GnuPG/Bash/coreutils dal repository firmato Alpine. Container
non root, filesystem readonly, tmpfs privato e sorgente montata readonly.
Nessun socket Docker o porta pubblicata. Cifratura con network=none; upload
in processo separato, senza chiave privata e senza dump in chiaro montato.

Configurazione KEY=value strettamente allowlist (mai source): S3_ENDPOINT,
S3_BUCKET, S3_PREFIX, S3_REGION, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY.
Endpoint HTTPS sul dominio contabostorage.com; bucket gia creato e privato.
CA aggiuntiva facoltativa da file, mai disabilitare la verifica TLS.
Preflight --check controlla solo input e involucro OpenPGP, senza rete.
Invio copyto con --immutable e checksum, key remota contenente SHA256 del
cifrato; niente delete, sync, creazione bucket o retention implicita.
Retry limitati (3/2), timeout connessione 5s, operazioni 30s, durata massima5m.
Config rclone generata in directory temporanea 0700 con file0600; ambiente
client ripulito, output SDK non inoltrato per evitare URL firmati/credenziali.
Controllo involucro non certifica integrita/recuperabilita senza chiave privata.

Rclone puo richiedere lettura metadati oltre alla scrittura; non promettere
permessi write-only prima della prova delle policy reali Contabo. Endpoint,
bucket, credenziali e retention reale ancora non forniti: niente accesso live.

Fonti:
- https://rclone.org/commands/rclone_copyto/
- https://rclone.org/flags/
- https://contabo.freshdesk.com/en/support/solutions/articles/103000411092-object-storage-s3-compatibility-protocols-and-connection-settings

## Allineamento branch (2026-11-26)

Branch rinominato feature/backup-offsite. Fetch origin/main eseguito:
main=f0f2e7e, ancora privo dei tre commit documentali 4944ddb,817e509,72e47f6.
Il branch conserva base72e47f6 e le modifiche locali; fast-forward non possibile,
nessun merge/rebase/commit forzato. Da riconciliare prima della PR, preservando
SIP-037..040 e aggiornamento archiviazioni che mancano ancora su main remoto.

## Esito B (2026-11-26)

Implementati Dockerfile/.dockerignore, tools.sh, upload.sh e helper condiviso
private-inputs.sh (estratto dalla cifratura, regressione invariata). Config di
esempio senza segreti, README aggiornato. Suite effettivamente eseguite:

- 19 verifiche cifratura;
- 20 controlli contratto trasporto offline con client simulato;
- 10 verifiche reali su S3 TLS usa-e-getta: cifratura nonroot senza rete,
  preflight senza rete, upload, retry, CA/hostname/autenticazione rifiutati,
  download/decifratura identica, collisione remota rifiutata, nessuna porta host.

Suite offline eseguite anche nel container Alpine/GnuPG2.4.9/rclone1.76.0;
corrette incompatibilita regex musl e riconoscimento pacchetto OpenPGP AEAD.
Per i soli test mock la tmpfs consente exec; e2e/runtime usa tmpfs noexec.
Container e rete e2e rimossi, immagine test conservata. Nessun secret reale,
bucket Contabo, database o VPS usato. Non e un ripristino MySQL o Besu.

Non completati: packaging manifest duraturo, integrazione timer/backup locali,
policy e credenziali reali Contabo, retention approvata, ripristino DB/chain,
review indipendente e attivazione produzione. Nessun commit/push/deploy.
