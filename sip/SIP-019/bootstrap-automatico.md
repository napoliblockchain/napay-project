# SIP-019 / Bootstrap automatico di Napay v2

- Stato: implementato nel compose locale Napay, verificato su copia reale del backup.
- Fonte unica: dataset `napay_v2`. Nessun import dello schema `napay` legacy.
- Compose centrale/poawallet non modificati. Runtime web completo non ancora verificato.

## Avvio previsto

```text
preflight: .env privato, secret esterno, dataset esterno, volume persistente
    -> MySQL healthy (query autenticata sul server definitivo)
    -> bootstrap: lock DB, import v2, verifica hash, migration, nuova verifica
    -> stato persistente complete
    -> entrypoint web verifica stato/schema/versione
    -> Apache e healthcheck HTTP
```

`docker/up.sh` crea il volume esterno solo se assente e avvia Compose con build
e attesa readiness. Nessun comando SQL/import manuale. Configurazione iniziale
richiede credenziali/chiavi originali, dataset e dipendenze applicative validi.

```sh
./docker/up.sh /percorso/napay.env --check
./docker/up.sh /percorso/napay.env
```

Il preflight non stampa il JSON completo Compose (contiene segreti), vieta
secret/dataset nel repository, verifica permessi owner-only e UID proprietario.
`--check` non crea volumi o avvia servizi. `NAPAY_STACK_WAIT_SECONDS` dimensiona
attesa globale (default 3600); va mantenuta coerente col budget bootstrap e
healthcheck. Script Bash, Docker Compose con supporto condizioni dipendenza.

Il job usa `service_healthy`; web usa `service_completed_successfully` e
controllo anche nel proprio entrypoint, valido dopo restart del daemon.
Non aspettare tutte le applicazioni healthy prima dell'import: sarebbe una
dipendenza circolare. Il gateway puo restare in manutenzione finche web non e
pronto. Riferimento: [ordine avvio Docker](https://docs.docker.com/compose/how-tos/startup-order/).

## Dataset e riservatezza

Preparato dal backup fisico del 2026-10-22, recuperato su copia offline 8.0.46:
`/home/sergio/.local/share/napay/import-v2-20261022/`.
Directory 0700, file 0600: `napay-v2.sql` e `manifest.json`. Solo `napay_v2`,
11 tabelle e 47 righe originali; nessun altro database del datadir incluso.
L'archivio originale non e stato modificato. La copia fisica temporanea e stata
rimossa; dataset privato conservato per test/deploy successivi.

Manifest formato 1: sorgente, SHA-256 SQL, fingerprint schema e digest/conteggio
per tabella/colonne originali. Non e una firma di provenienza: SQL e manifest
vanno prodotti, revisionati e distribuiti da soggetto fidato. Anche gli hash
vanno custoditi in area privata. SQL e codice privilegiato sul DB destinazione.

`export-v2-manifest.php` verifica sorgente esattamente `napay_v2`, elenco noto di
11 tabelle e assenza di trigger/routine/eventi non revisionati. La preparazione
del dataset avviene prima del deploy, non ripristina l'intero datadir dentro
il normale bootstrap. Nessun fallback se manca il dataset v2.

`NAPAY_IMPORT_DIR` punta alla directory privata, montata read-only SOLO nel job.
Il web non riceve dump/manifest, socket o root secret. Job UID/GID configurabili
(default 1000:1000) devono coincidere col proprietario dei file; root filesystem
read-only, tmpfs privata, capability rimosse e no-new-privileges.

## Trasporto e credenziali

Job usa account DB applicativo, non root, con attuali privilegi sul solo DB.
Il client SQL importa tramite volume socket Unix dedicato: autenticazione
obbligatoria, nessun bypass grant e nessuna disabilitazione verifica TLS.
Il socket non e pubblicato sull'host o montato nel web; non contiene datadir.
MySQL e PHP comunicano anche sulla rete database interna. DSN accettato:
servizio `mysql`, porta interna 3306 e dbname coerente con `DB_DATABASE`.

Password client in file temporaneo 0600, mai argv o log. SQL local-infile
disabilitato; output subprocessi soppresso per non divulgare query/dati.
Runtime console in `/tmp`, non nella sorgente montata read-only.
Chiavi originali e credenziali non vengono generate o ruotate dal job.

## Stato persistente e ripetibilita

`_napay_bootstrap` nel DB registra checksum dataset/manifest, versione catalogo
migration, fingerprint schema e fase `importing`, `upgrading`, `complete` o
`failed`. Lock MySQL esclusivo impedisce bootstrap concorrenti.

Prima importazione: destinazione interamente vuota, altrimenti STOP senza
cancellare dati. Import logico, confronto schema e hash/conteggi di tutte le
11 tabelle; migration Yii non interattive; confronto dati delle 10 tabelle
applicative originali (migration puo acquisire nuove righe). Solo poi complete.

Sui successivi avvii: stesso dataset/versione/schema -> verifica e no-op.
Non confrontare i dati correnti col vecchio snapshot: nuove operazioni utente
devono restare intatte. Nessun reimport, reset o duplicazione automatica.
Schema/storico essenziale discordante, dataset o catalogo migration diverso:
STOP. Upgrade di un catalogo successivo richiede percorso pianificato; mai
risolto reimportando il backup iniziale.

Import SQL/DDL non totalmente transazionale. Fase incompleta/failed dopo crash
non viene ripetuta alla cieca: writer bloccati e recupero su nuova destinazione
vuota concordata. Il codice operativo non esegue DROP DATABASE o pulizie.
Solo la suite usa reset su database fittizio dal nome vincolato.

## Tempi e prove

Retry DB con backoff e budget `NAPAY_DB_WAIT_SECONDS` (default 120), niente
sleep fisso come prova di disponibilita. Processi import/migration sorvegliati
entro `NAPAY_BOOTSTRAP_SECONDS` (default 1800), errori/timeout bloccano avvio.
Start period e retry MySQL configurabili; deploy deve prevedere anche tempo
build, inizializzazione DB e healthcheck web.

Suite locale: `tests/docker/bootstrap.sh`, dataset esplicito e vendor Yii di
test compatibile. Verifica 32 asserzioni PHP e 2 controlli Compose: import reale,
hash originali, upgrade, writer dopo job, retry/no-op dopo nuove scritture,
checksum/mancanza dati, lock concorrente, target non vuoto, SQL errato/parziale,
timeout, stato interrotto, versione errata e persistenza dopo down -v.
Writer fittizio CLI senza porte pubblicate: non e uno smoke test del sito reale.

Regressioni distinte: 34 controlli schema v2, 8 backup/persistenza, 23 .env,
lint PHP/shell. Test non usano chiavi originali: decifratura e sessioni storiche
NON dimostrate. Runtime vendor Napay incompleto; prima di deploy operativo
servono dipendenze installate/verificate, chiavi originali, smoke HTTP/login,
backup automatici/retention, integrazione Caddy centrale e cutover approvato.
