# TIP-020 - Mappa legacy → v2 (bozza, fase 1)

Bozza da confermare prima delle fasi 2 e 3. Solo struttura, nessun dato.
Inventario: [inventario-legacy.md](inventario-legacy.md).

## Regole generali

- Import idempotente: ogni riga v2 tiene l'ID legacy (colonna `legacy_id` o
  tabella di raccordo). Si può rieseguire senza creare doppioni.
- Il legacy si legge e basta: mai scritture su `napay_legacy`.
- Importi: `float` legacy → `DECIMAL(10,2)` v2, arrotondati al centesimo.
  Totali riconciliati per anno, tipo e stato.
- Date: `date` legacy → `date` v2. Timestamp Unix → `datetime` UTC.
- Charset: legacy utf8mb3 → v2 utf8mb4, senza perdita.

## Utenti e soci

| Legacy `np_users` | v2 | Note |
| --- | --- | --- |
| `id_user` | `users.legacy_id` (nuova) | raccordo |
| `email` | `users.email` | chiave di abbinamento (minuscolo); 1 sola già presente in v2 |
| `email` | `users.username` | **da decidere**: in v2 lo username è obbligatorio; proposta: email |
| `password` (bcrypt `$2y$`) | `users.password` | copiato così com'è, da verificare con il login v2 |
| `name`, `surname` | `first_name`, `last_name` | |
| `status_activation_code` | `is_active` | |
| `activation_code` | `activationCode` | solo se non attivato |
| `id_users_type` | `privilege_id` | Amministratore → Administrator (50), Commerciante → Merchant (30) + `is_merchant`, Socio → User (0); POS e Istituto: **da decidere** |
| `id_carica` | nuova tabella cariche/ruolo associativo | Segretario: vedi domande |
| `corporate`, `denomination`, `vat`, `address`, `cap`, `city`, `country` | profilo socio (nuova tabella) o `merchants` per i commercianti | persona fisica o giuridica: serve per quota e ricevuta |
| `ga_secret_key` | — | 2FA legacy: **da decidere** (proposta: non migrare, riattivazione 2FA in v2) |
| — | `oauth_provider` | `SELF` |

Consensi: `np_consensus` è vuota nel backup. Se la produzione ne ha, i
consensi vanno in `user_consensus` con il loro timestamp.

## Associazione (nuove tabelle v2)

| Legacy | v2 proposta | Note |
| --- | --- | --- |
| `st_quote` | `membership_fees` | descrizione, durata (`extension`), importo DECIMAL |
| `st_tipo_pagamenti` | `payment_methods` | Bitcoin, Paypal, Token, Bonifico, Contanti, Esente; `permission` = livello minimo per registrarlo a mano |
| `st_pagamenti` | `membership_payments` | utente, quota, anno, progressivo ricevuta, importo, tipo, data registrazione/inizio/scadenza, stato, riferimenti esterni (`id_invoice_bps`, `paypal_txn_id`) |
| `st_cariche` | `association_roles` | carica collegata al tipo utente |
| `st_verbali` | `assembly_minutes` | data, descrizione, file. `url_verbale`: i file vanno recuperati dallo storage legacy |

Stati pagamento legacy: `paid`, `new`, `expired`, `invalid` (più quelli
BTCPay). Proposta v2: `paid`, `pending`, `expired`, `invalid`, mappati 1:1.
Lo stato "in scadenza" dei soci si calcola da `data_scadenza`, non si salva.

## Impostazioni (`np_settings_webapp`, chiave/valore)

Valori non segreti → `settings` v2: dati GDPR del titolare, importi quota
(`quota_iscrizione_socio`, `quota_iscrizione_socioGiuridico`), progressivi
ricevute (`progressivo_ricevute_*`), denominazioni.

**Segreti salvati in chiaro nel DB legacy** (`PAYPAL_CLIENT_SECRET`,
`BPS_Admin_Password`, `sshpassword`, `poa_sealerPrvKey`, `telegramToken`,
`exchange_secret`, `googleAppSecret`, `GoogleOauthClientSecret`,
`reCaptcha2PrivateKey`, `VapidSecret`, ...):
- **non** si migrano nel DB v2: vanno solo in variabili d'ambiente;
- vanno considerati esposti (sono presenti in backup e copie) e **ruotati**
  prima del cutover.

## Fuori dal perimetro di questa mappa

`bolt_*` (wallet cittadino, TIP-006 REJECTED), `dali_*` (altro progetto
nello stesso schema), `np_comuni_italiani` (già presente in v2), moduli
commercianti/POS/transazioni (fase 6).

## Decisioni utente (2026-11-11)

1. **Login solo con email, per tutti** (soci importati e utenti v2 esistenti).
   Lo username v2 non serve più per accedere: per gli importati vale l'email.
2. **Si migrano tutti gli utenti**, anche POS e Istituto: in produzione ci
   sono, il backup locale ne è privo ma la struttura è identica.
3. **Segretario = admin.** Nel legacy tutte le cariche di vertice (Presidente,
   Vice Presidente, Tesoriere, Segretario) sono di tipo Amministratore →
   privilegio Administrator. La carica resta come titolo del socio
   (`association_roles`), separata dal privilegio.
4. **2FA disattivata**: `ga_secret_key` non si migra, la 2FA si riattiva più
   avanti con nuova registrazione.
5. **File dei verbali**: nel legacy sono in `<cartella app>/protected/verbali/`
   (`Yii::app()->basePath . '/verbali/'`), nome file = `url_verbale`
   (md5 casuale `.pdf`). Sul VPS si trovano con:
   `find / -type d -path '*/protected/verbali' 2>/dev/null`.
   La cartella `protected/privatekeys/` contiene le chiavi del vecchio pairing
   BTCPay (API v1): non si migra, BTCPay passa a Greenfield.
6. **Nessun dump manuale**: al primo avvio v2 legge direttamente il DB legacy
   e migra tutto in automatico. Lo spegnimento del vecchio sistema lo fa
   l'utente quando v2 è pronto.

## Design migrazione automatica (proposta)

- Sorgente da env: `LEGACY_DB_DSN`, `LEGACY_DB_USERNAME`, `LEGACY_DB_PASSWORD`
  (utente MySQL di **sola lettura** sul DB legacy) e `LEGACY_FILES_DIR`
  (cartella verbali montata in sola lettura). Senza `LEGACY_DB_DSN` non viene
  importato nulla.
- Esecuzione: job di bootstrap, dopo import/upgrade v2. Il web parte solo se
  il job termina bene, come oggi.
- **Ripetuto a ogni avvio** finché `LEGACY_DB_DSN` è impostata: upsert per ID
  legacy, così le novità del vecchio sistema (nuovi soci, pagamenti, stati)
  arrivano anche se v2 viene avviato prima dello spegnimento del vecchio.
  Dopo lo spegnimento si toglie `LEGACY_DB_DSN` e resta l'ultima fotografia.
- Finché l'import è attivo, il legacy è la fonte autorevole per i record
  importati. Gestione e pagamenti dell'associazione in v2 sono **in sola
  lettura**, per non avere due sistemi che scrivono (vedi TIP-019).
- Utente con email già presente in v2: si tiene l'utente v2 (password e
  privilegio), si collega l'ID legacy e gli si agganciano quote e pagamenti.
- Ogni esecuzione registra conteggi e totali per anno, tipo e stato, e si
  ferma se legacy e v2 non quadrano. Il log non contiene dati personali.
- Prerequisito: oggi il bootstrap v2 fissa l'hash delle migration al primo
  avvio e poi blocca l'app se ne arrivano di nuove. Serve una fase di
  **upgrade**: migration nuove applicate in automatico all'avvio, con
  controllo che i dati esistenti non cambino.

## Domande aperte

1. Utenti POS e Istituto: ruolo v2? Proposta: importati con il tipo legacy
   conservato nel profilo. Istituto → User. POS → disattivato finché il
   modulo POS non è portato (TIP-004).
2. Sola lettura dell'associazione in v2 durante l'import ripetuto: confermare.
