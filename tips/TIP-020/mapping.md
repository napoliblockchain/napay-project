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

## Domande aperte

1. Username v2 per i soci importati: uso l'email?
2. Utenti POS e Istituto: si migrano? Con quale ruolo?
3. Segretario: nel legacy nasce dalle cariche (`id_carica`), in v2 non esiste.
   Nuovo privilegio (es. livello 40) o ruolo associativo?
4. 2FA legacy (`ga_secret_key`): migrarlo o chiedere la riattivazione?
5. File dei verbali (`url_verbale`): dove sono sul server legacy?
6. Dump della produzione online: chi lo fa e quando (serve anche per
   riconciliare quote 2023–2026)?
