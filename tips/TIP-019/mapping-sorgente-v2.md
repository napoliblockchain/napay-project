# TIP-019 / Mapping sorgente v2 e destinazione Docker

- Stato: mapping 1:1 documentato; compatibilita schema implementata e testata
  su fixture locale e copia reale. Bootstrap automatico collegato al compose
  locale; runtime HTTP completo ancora da verificare.
- Fonte unica: `napay_v2` dal backup del 2026-10-22.
- Esclusione: schema `napay` legacy, wallet e altri database dell'archivio.

## Decisione di perimetro

Non e una conversione Yii1 -> Yii2. E un trasferimento del database Yii2
esistente in MySQL Docker, seguito da aggiornamenti compatibili col codice.
Il test precedente ha usato `napay` come nome destinazione; il nome e
configurabile e NON identifica il vecchio schema omonimo. Per evitare ambiguita,
il manifest di import deve dichiarare separatamente schema sorgente e target;
`DB_DSN` e `DB_DATABASE` devono indicare lo stesso target.

Nessuna scansione con scelta automatica del DB per somiglianza del nome.
Nessun fallback al legacy se manca il dump v2. Nessun merge tra i due dataset,
nessun import di utenti/grant o di altri database del backup fisico.

## Regole comuni

| Oggetto | Regola |
| --- | --- |
| Tabelle e colonne presenti | Trasferimento omonimo 1:1, prima di upgrade approvati |
| PK, FK e auto_increment | Conservare identita e relazioni; verificare prossimo ID |
| Hash password | Copia byte-per-byte, niente rehash senza password originale |
| authKey/accessToken | Conservare durante restore; eventuale revoca sessioni e scelta distinta approvata |
| Ruoli/privileges | Conservare ID/codici/livelli v2; non rilanciare seed di ruoli |
| Stato utenti | Conservare is_active/is_merchant, niente attivazioni automatiche |
| Consensi | Conservare valori e timestamp, senza beforeSave() che li rigenera |
| Timestamp/charset/collation | Nessuna conversione implicita; confrontare su target |
| Valori JSON e boolean | Preservare tipo e significato; verificare integrita |
| Dati cifrati | Conservare byte e SECRET_HASH_KEY originale; decifratura da provare separatamente |
| Chiavi cookie | Configurazione esterna originale, non ricavata dal dump e non rigenerata silenziosamente |
| Impostazioni BTCPay | Conservare valori v2, nessuna sostituzione con credenziali admin legacy |
| Trigger/routine/eventi | Inventariare e revisionare; event scheduler resta OFF |
| Upload/allegati | Copia separata quando presenti, non contenuti nel dump DB |

Ripristino tramite dump fidato revisionato e account di bootstrap limitato al
necessario; web non riceve root secret. Non usare SignupForm/Controller/AR
per ricreare dati: produrrebbero nuovi identificativi, log o timestamp e
potrebbero chiamare servizi esterni.

## Regole per tabella

| Sorgente v2 | Destinazione | Verifica / upgrade |
| --- | --- | --- |
| `privileges` | `privileges` | Stessi ID/codici/livelli; nessun duplicato seed |
| `users` | `users` | Stessi ID/hash/stato/chiavi; riconciliare activationCode |
| `merchants` | `merchants` | Stessi dati e user_id, nessun merchant generato |
| `stores` | `stores` | Stessi ID/merchant_id; nessun provisioning BTCPay |
| `storesettings` | `storesettings` | Tutti i campi omonimi, JSON e collegamenti conservati |
| `user_consensus` | `user_consensus` | Date e consensi immutati; nessuna accettazione inventata |
| `settings` | `settings` | id/description/code/value conservati, valori riservati |
| `webhooks` | `webhooks` | Record locali conservati, nessuna chiamata remota |
| `logs` | `logs` | Storico immutato, niente troncamenti o scrubbing distruttivo |
| `np_comuni_italiani` | `np_comuni_italiani` | Stessi campi id/citta/provincia/sigla; vuoto resta vuoto |
| `migration` | `migration` | Riconciliazione nomi/schema PRIMA delle migration pendenti |

## Upgrade necessari o da decidere

### Storico migration utenti

Il nome registrato nel backup non coincide col file attuale. L'importer deve
riconoscere questa versione sorgente e verificare struttura reale di users.
Non registrare come eseguita una migration senza verificarne effetti; non
rilanciare createTable su tabella ripristinata. Implementato ramo compatibilita
nella migration canonica: accetta users gia esistente solo con marker storico
esatto e struttura verificata da `components/db/V2UsersSchema.php` (colonne,
PK/auto_increment, FK/cascade, InnoDB e collation). Nessun DROP/CREATE users.
Il marker originale rimane; Yii registra anche l'esecuzione compatibile del
nome canonico. Le differenze additive sono risolte da migration successive.
Schema o storico non riconosciuti bloccano l'upgrade, senza merge di dati.

### activationCode

Campo nullable atteso dal codice, mancante nel backup. Upgrade additivo dopo
restore; nessun riuso di token di altri software e nessun reset password
inviato automaticamente. Implementata
`m261023_120000_add_activation_code_to_users`: non modifica un campo gia
compatibile e rifiuta tipi/lunghezze/default diversi. Ripetibile anche dopo
DDL riuscito ma precedente interruzione della registrazione nello storico.

### auth

Tabella prevista da `Auth`, `Users::getAuths()` e `AuthHandler`, ma assente
nel backup. Implementata `m261023_120100_create_auth_table`: tabella vuota,
FK users con cascade e identita provider univoca e case-sensitive.
Collation `utf8mb4_0900_bin` distingue anche spazi finali negli identificativi
opachi; riferimento [collation MySQL](https://dev.mysql.com/doc/refman/8.4/en/charset-mysql.html).
Nessun account social o collegamento dedotto dai campi degli utenti.
Questo rende disponibile lo schema del model, NON abilita o certifica SSO:
AuthHandler contiene altre assunzioni/campi e integrazioni non verificati.

## Criteri di riconciliazione

Prima dell'upgrade: 11 tabelle, 47 righe nel backup di prova, conteggi per
tabella e contenuto logico identici alla sorgente. Dopo upgrade: variazioni
ammissibili solo per DDL/storico esplicitamente previsti; identita, ruoli,
password, riferimenti e dati applicativi originali invariati.

Test locale eseguito su MySQL 8.4 con PHP 8.3.36 e Yii 2.0.55 di test:
34 controlli, DB nuovo e fixture dello schema storico, retry/no-op,
schema incompatibile, FK/collation, Unicode, contatore ID, consensi,
hash/chiavi invariati e relazione Users/Auth. Non usati dati operativi.

Job automatico ora provato sulla copia del backup: hash/conteggi prima e dopo
migration, nuove scritture non sovrascritte, concorrenza, errori, timeout,
persistenza e gating writer. Restano test funzionali reali:
Unicode/timezone, login/ruoli, consensi, lettura impostazioni senza chiamate
esterne e decifratura con chiavi originali. Dati sensibili mai nei log o report
pubblici. Nessuna importazione operativa eseguita. Le nuove migration sono
state applicate solo a copie locali, mai al backup originale o a DB operativo.

Rollback delle due migration additive non automatico: non eliminare token o
identita; ripristino da backup approvato. DDL MySQL non e interamente atomico:
creazione auth parzialmente fallita richiede recupero controllato, non drop
automatico e non riavvio dei writer.
