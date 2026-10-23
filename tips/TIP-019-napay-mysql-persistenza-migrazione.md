# TIP-019 - Napay: MySQL dedicato, persistenza e ripristino dati v2

- Stato: IN_PROGRESS
- Area: Backoffice / Database / Docker
- Repo: `napay`, `napay-project` (documentazione)
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-10-23

## Contesto

Napay usava MySQL host. Occorre conservare il database Yii2 esistente
`napay_v2` e le chiavi originali, separando vita dei container e vita dei dati.
Chiarimento utente del 2026-10-23: `napay` legacy NON deve essere usato come
sorgente. Non e prevista conversione Yii1 -> Yii2 ne fusione dei due schemi.
Il lavoro parallelo su poawallet resta escluso da questa proposta.

## Proposta

- MySQL 8.4 LTS dedicato nel compose Napay, previa compatibilita sorgente.
- Rete database interna, nessuna porta MySQL pubblicata sull'host.
- Porta HTTP diagnostica invariata: `127.0.0.1:18120`.
- Volume esterno nominato `napay_mysql_data`, non eliminato da `down -v`.
- Root secret esterno al repository, montato solo nel database.
- `.env` per credenziali applicative; nessun `secrets.php`.
- Tool backup logico e restore solo con conferma e destinazione vuota.
- Event scheduler OFF per impedire esecuzione automatica eventi importati.
- Runbook con inventario, prova, cutover, riconciliazione, rollback e backup.

## Criteri di accettazione

- Container pronto tramite healthcheck TCP autenticato, web attende MySQL.
- Dati e storico migrazioni sopravvivono alla ricreazione dei container.
- Backup ripristinabile su nuovo volume; restore rifiuta DB non vuoto.
- Segreti e dump esclusi da Git/build; nessuna credenziale root nel web.
- Prima del cutover reale: versione sorgente verificata, conteggi/totali e
  decifratura confrontati, smoke test funzionali e rollback approvati.
- Prima installazione con dati preesistenti: import AUTOMATICO del solo dataset
  `napay_v2`, senza comandi manuali o prompt operatore. Sorgente/destinazione
  dichiarate nella configurazione di deploy; nessun fallback al legacy.
- Job di bootstrap dopo MySQL healthy; web/worker/scheduler operativi solo
  dopo completamento riuscito di import, riconciliazione schema e verifiche.
  Niente attese fisse o dipendenze circolari dall'healthcheck del web.
- Import iniziale ripetibile senza duplicazioni o sovrascritture silenziose,
  con modalita verifica, report e blocco su destinazione incompatibile.
  Nessun import legacy automatico a ogni avvio del container.

## Impatto

`napay/docker-compose.yml`, `.env.example`, esclusioni Git/build,
`docker/mysql-tools.sh`, `tests/docker/mysql.sh`, documentazione Docker.
Schema aggiornato solo con migration additive; connessione utf8mb4 coerente
con la sorgente, senza conversioni delle tabelle. PHP e compose centrale invariati.
Il compose Napay e autonomo: integrazione con orchestratore/Caddy resta distinta.

## Note implementative

Guida operativa: `napay/docker/MYSQL-MIGRATION.md`.
Non riutilizzare fisicamente il datadir host. Importare schema, dati e storico
Yii senza rilanciare ciecamente migrazioni di creazione. Preservare chiavi
originali `SECRET_HASH_KEY` e configurazione applicativa pertinente.
Backup locale identificato come MySQL 8.0.46 e recuperato su copia isolata.
Per altre sorgenti: MySQL 5.7 richiede percorso validato via 8.0; MariaDB
richiede analisi dedicata. Tag di linea `mysql:8.4`
da registrare con digest approvato al rilascio. Volume permanente non e backup.

## Verifica repository

Test con dati fittizi e volumi temporanei, nessun DB operativo utilizzato.
`sh tests/docker/mysql.sh`: 8 controlli passati, validazione compose, password obbligatoria,
assenza porte host, identificatori validati, consenso restore, import/backup,
rifiuto target non vuoto, persistenza dopo `down -v`, restore su nuovo volume.
`tests/config/environment.php`: 23 controlli configurazione, PHP 8.3.36.
Controlli shell `sh -n` e `git diff --check`.

Da completare: dipendenze runtime Napay installabili/verificate,
decifratura con chiavi originali, smoke applicativo,
scheduling backup/retention/allarmi, integrazione orchestratore e cutover
approvato. Nessun import operativo eseguito.

## Prova con backup locale - 2026-10-23

Archivio originale: `/home/sergio/backup-mysql-datadir-2026-10-22.tgz`,
738726486 byte, contenente datadir fisico (non dump SQL).
L'archivio originale non e stato modificato, ed e stato montato read-only.
SHA-256 archivio: `cc32f02e13db3aca3a1b614c62a03e5bcd607581fe2c6bc966300ae581c157b1`.

Procedura eseguita:

1. Estrazione in volume nuovo temporaneo; recupero con MySQL 8.0.46, identico
   alla versione registrata nel backup. Nessuna rete (`--network none`),
   nessuna porta pubblicata, eventi e binlog disattivati. Accesso senza grant
   limitato a questa copia offline per esportazione, mai a servizi operativi.
2. Identificazione di `napay_v2`, corrispondente alle tabelle dei model Yii2,
   e di `napay`, schema legacy differente e condiviso con componenti storici.
3. Dump logico `napay_v2` con snapshot InnoDB; dump legacy con lock globali
   sulla sola copia offline, per includere coerentemente tabelle MyISAM.
4. Import mediante `mysql-tools.sh restore --confirm-empty-target` in MySQL
   8.4.13 temporaneo: `napay_v2` importato come `napay`, vecchio `napay`
   importato separatamente come `napay_legacy`. Nessuna fusione o conversione.
5. Confronto conteggi esatti per tabella, colonne, indici, chiavi e collazioni.
   Confronto byte-per-byte di dump dati canonici, ordinati per chiave primaria
   quando disponibile, senza commenti o DDL: identici per entrambi gli schemi.
6. `CHECK TABLE`: 63 tabelle OK, nessun warning o errore.
7. `compose down -v` e ricreazione del solo progetto temporaneo: volume
   esterno conservato, contenuto logico di entrambi gli schemi ancora identico.

| Schema nel backup | Schema di prova | Tabelle | Righe totali | Esito |
| --- | --- | --- | --- | --- |
| `napay_v2` | `napay` | 11 | 47 | Import e confronto OK |
| `napay` | `napay_legacy` | 52 | 13839 | Import e confronto OK |

Il conteggio 47 comprende 25 log e 11 righe dello storico migrazioni; non e
una migrazione dei 13839 record legacy nel nuovo modello Yii2.
Hash password e valori cifrati sono conservati byte-per-byte; la decifratura
non e stata provata, perche non sono state recuperate/usate le chiavi originali.
Nessun avvio del web o di integrazioni esterne, nessuna modifica a poawallet.
Non eseguiti smoke test applicativi o riconciliazione funzionale/economica.
Le risorse di prova e i dump temporanei vengono rimossi dopo la verifica;
il backup originale resta disponibile per il prossimo passo.

Conclusione della prova tecnica: entrambi i database sono recuperabili in
MySQL 8.4. Questa prova storica NON autorizza l'import del legacy: il perimetro
corretto successivamente dall'utente usa solo `napay_v2`.

## Analisi punti 1-2 e avvio automatico - 2026-10-23

- [Inventario sorgente v2](TIP-019/inventario.md): tutte le 11 tabelle,
  conteggi e metadati strutturali senza valori sensibili.
- [Mapping v2 verso MySQL Docker](TIP-019/mapping-sorgente-v2.md): copia 1:1,
  conservazione identita/chiavi e upgrade compatibili, nessuna conversione legacy.
- [Bootstrap automatico previsto](TIP-019/bootstrap-automatico.md): job dopo
  MySQL healthy e writer dopo job riuscito, timeout e stato persistente.

Blocchi verificati: `activationCode` mancante nel backup, migration utenti
registrata con nome diverso dal file corrente, model `Auth` senza tabella
`auth` nella sorgente e nelle migration. Prima di `yii migrate` occorre
riconciliazione verificata: non ricreare users o inventare storico eseguito.

La fase iniziale ha completato l'analisi documentale richiesta. Punto 4 resta
prova locale; punto 5
integrazione definitiva solo dopo test. Il comando console futuro e il motore
del job automatico, non un passaggio manuale di installazione.

## Compatibilita schema implementata - 2026-10-23

- Guard `napay/components/db/V2UsersSchema.php`: riconoscimento rigoroso del
  marker storico e schema users, senza modificare dati o indovinare identita.
- Migration utenti canonica riconosce la versione storica verificata senza
  ricreare users; storico originale preservato e nuova esecuzione registrata.
- Migration additive per activationCode nullable e auth vuota con FK e vincolo
  provider/ID univoco case-sensitive. Nessuna abilitazione automatica SSO.
- Test `napay/tests/docker/v2-schema.sh`: 34 controlli passati su MySQL 8.4,
  PHP 8.3.36 e Yii 2.0.55 da vendor di test compatibile, non installazione runtime.
- Regression config: 23 controlli passati; lint PHP e shell senza errori.

Solo Napay modificato; poawallet e compose centrale non toccati. Nessun DB
operativo modificato. Questo paragrafo descrive il primo step schema;
avanzamento bootstrap locale riportato sotto. Restano dipendenze runtime
Napay e test applicativi reali.

## Bootstrap automatico locale verificato - 2026-10-23

- Dataset v2 estratto su copia offline 8.0.46, conservato privato fuori Git:
  `/home/sergio/.local/share/napay/import-v2-20261022/` (0700, file 0600).
  Backup originale invariato; nessun import legacy.
- Job non-root dopo MySQL healthy: checksum, lock esclusivo, import via
  socket privato autenticato, verifica hash, migration e seconda verifica.
- Stato `_napay_bootstrap` persistente e confronto versione/schema; retry di
  installazione completa = no-op, nuove scritture mai sovrascritte.
- Fase parziale/failed, dataset errato o target non vuoto bloccano il bootstrap;
  nessun DROP/reset nel codice operativo.
- Web dipende dal successo job, entrypoint e healthcheck verificano DB pronto.
  `docker/up.sh` preflight input privati e crea volume esterno se assente.
- 32 controlli automatici PHP + 2 Compose passati con exit 0, inclusi cold
  start, writer dopo job, concorrenza, errore/timeout e down -v/no-op.
- Regressioni: 34 schema v2, 8 backup/persistenza, 23 ambiente; lint PHP/shell.

Solo stack locale Napay. Compose centrale/poawallet intatti. Prove con vendor
Yii isolato e writer CLI fittizio, NON sito HTTP completo. Chiavi fittizie nei
test: decifratura/sessioni originali non provate. Da completare: vendor Napay,
chiavi originali, smoke HTTP/login, backup/retention e integrazione gateway
centrale/cutover approvato. Stato TIP resta IN_PROGRESS.
