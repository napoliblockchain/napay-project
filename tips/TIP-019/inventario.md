# TIP-019 / Inventario della sorgente Napay v2

- Stato: riconciliazione schema implementata/testata su fixture e copia reale
  tramite bootstrap locale; runtime HTTP/cutover non verificati.
- Rilevato: 2026-10-23. Branch: `feature/v2-yii2-php83-docker`.
- Perimetro corretto dall'utente: solo `napay_v2`; `napay` legacy NON e sorgente.

## Fonte e metodo

Archivio `/home/sergio/backup-mysql-datadir-2026-10-22.tgz`, checksum nella
[TIP principale](../TIP-019-napay-mysql-persistenza-migrazione.md).
Recupero esclusivamente su copia offline MySQL 8.0.46, senza rete o eventi.
Ispezione information_schema, COUNT(*) e versioni della tabella migration.
Non sono stati esportati dati personali, valori delle impostazioni, password,
chiavi o default SQL nella documentazione. Backup originale invariato.

Il nome schema, le tabelle e lo storico corrispondono all'applicazione Yii2.
Questo non dimostra da solo quale deploy fosse effettivamente attivo o se
il backup sia l'ultimo operativo: verifica necessaria prima del cutover.

## Tutte le tabelle sorgenti

| Tabella | Righe | Trattamento |
| --- | ---: | --- |
| `logs` | 25 | Conservare audit, ID, timestamp e riferimenti utente |
| `merchants` | 1 | Conservare ID e relazione users |
| `migration` | 11 | Conservare e riconciliare con catalogo repository |
| `np_comuni_italiani` | 0 | Conservare; non integrare dal legacy implicitamente |
| `privileges` | 3 | Conservare ID, codici e livelli; nessun reseed |
| `settings` | 3 | Conservare codici/valori riservati; non stampare nei log |
| `stores` | 0 | Ripristinare struttura/FK senza creare negozi esterni |
| `storesettings` | 0 | Ripristinare struttura/FK e tipi JSON/boolean |
| `user_consensus` | 2 | Conservare valori e date originali, senza callback AR |
| `users` | 2 | Conservare identita, hash, stato e chiavi originali |
| `webhooks` | 0 | Ripristinare struttura/FK; nessuna registrazione remota |

Totale: 11 tabelle InnoDB, 47 righe. Nessun accorpamento con i 13839 record
presenti nell'altro schema dell'archivio. Numero di righe non equivale a numero
utenti: 25 sono log e 11 appartengono allo storico migrazioni.

## Relazioni verificate

- `users.privilege_id` -> `privileges.id`.
- `merchants.user_id` -> `users.id`.
- `stores.merchant_id` -> `merchants.id`.
- `storesettings.store_id` -> `stores.id`.
- `user_consensus.user_id` -> `users.id`.
- `webhooks.store_id` -> `stores.id`.

## Differenze con repository corrente

1. `users.activationCode` assente nel backup; presente nel model, nel reset
   password e nella migration attuale. Serve upgrade additivo versionato,
   senza ricreare users o alterare hash/identita.
2. Storico: `m231113_093348_create_np_users_table`; repository:
   `m231113_093348_create_users_table`. Nome diverso, non una nuova tabella da
   creare. Non eseguire ciecamente `yii migrate`: prima verificare schema
   effettivo e introdurre riconciliazione controllata/versionata.
3. `Auth`, `Users::getAuths()` e `AuthHandler` referenziano tabella `auth`,
   assente nel backup. Aggiunta migration dedicata per lo schema vuoto;
   percorsi SSO e collegamenti social NON abilitati o verificati.
4. `config/db.php` usava charset connessione `utf8`; ora usa `utf8mb4`, coerente
   con la sorgente. Nessuna conversione implicita di tabelle/collazioni.
   Verifica Unicode inclusa nei test schema locali.

Lo storico del backup ha baseline + 10 migration; il numero corrispondente non garantisce
che nomi e definizioni siano coerenti col codice attuale.

## Verifiche gia eseguite

Nella prova precedente: restore v2 su MySQL 8.4.13, 11 conteggi corrispondenti,
dump dati canonici identici, colonne/indici/FK/collazioni corrispondenti e
persistenza verificata dopo `compose down -v` e ricreazione del container.
Questi sono test di restore, non test applicativi o di upgrade dello schema.
Successivamente: 34 test compatibilita/upgrade su fixture fittizie e job su copia
reale del backup: 32 controlli PHP + 2 Compose, hash conservati e persistenza OK.
Originale invariato. Verifiche funzionali del sito ancora da completare.

## Artefatti

- [Conteggi esatti](conteggi-tabelle.tsv): schema, tabella, righe.
- [Colonne](schema-colonne.tsv): schema, tabella, colonna, tipo, nullable,
  posizione; nessun dato o default SQL.
- [Mapping v2](mapping-sorgente-v2.md).
- [Avvio automatico previsto](bootstrap-automatico.md).
