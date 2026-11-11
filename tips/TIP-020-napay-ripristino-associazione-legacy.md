# TIP-020 - Napay: ripristino gestione associazione e migrazione dati legacy

- Stato: IN_PROGRESS
- Area: Backoffice / Associazione / Database
- Repo: `napay`, `napay-project` (documentazione, avvio locale)
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-11

## Contesto

La vecchia app Napay (Yii 1.1, branch `master`, release b2c2152 del 28/03/2023,
ancora online su `napay.napoliblockchain.it`) gestiva l'associazione:
soci, quote associative, pagamento quote in Bitcoin, PayPal o contanti,
transazioni dei commercianti, verbali e cariche. La v2 Yii2 (`new-version` e
successivi) ha riscritto solo utenti, commercianti, negozi e impostazioni.

TIP-019 limitava il perimetro dati al solo schema `napay_v2` (decisione utente
del 2026-10-23). **Decisione utente del 2026-11-11: il perimetro si estende.**
Le vecchie tabelle vanno migrate e le funzioni dell'associazione ripristinate
in v2, compreso il pagamento quote dentro l'app e fuori dall'app, come nel
vecchio sistema.

## Inventario vecchia app (da branch `master`)

Funzioni dell'associazione (prefisso tabelle `st_`):

| Funzione | Controller legacy | Tabelle |
| --- | --- | --- |
| Soci: lista, filtri attivi/in scadenza (45 gg)/scaduti, sollecito | Users, Userstype | `np_users`, `np_users_type`, `np_consensus` |
| Quote associative: versamenti, ricevuta, stampa, export Excel, grafico | Pagamenti | `st_pagamenti` |
| Importi quota (persona fisica / giuridica) | Quote, Settings | `st_quote`, `np_settings_webapp` |
| Tipi di pagamento (Bitcoin, PayPal, contanti) | TipoPagamenti | `st_tipo_pagamenti` |
| Paga quota da app (Bitcoin via BTCPay, PayPal) | Payfee | `st_pagamenti` |
| Paga quota da fuori app: login con email e password dedicato | Site `loginquota` | `np_users` |
| Notifiche pagamento (pubbliche): PayPal IPN, BTCPay, Bitpay, Coingate | Ipn | `st_pagamenti`, `np_transactions*` |
| Verbali di assemblea | Verbali | `st_verbali` |
| Cariche sociali | Cariche | `st_cariche` |
| Istituti, mailing ai soci | Institutes, Mailing | `np_institutes` |

Funzioni di pagamento dei commercianti (prefisso `np_`):

| Funzione | Controller legacy | Tabelle |
| --- | --- | --- |
| Transazioni (fatture BTCPay dei negozi) | Transactions | `np_transactions`, `np_transactions_data`, `np_transactions_info`, `np_invoices` |
| POS, prodotti, shop | Pos, Products, Shops | `np_pos`, `np_pos_invoices*`, `np_products`, `np_shops`, `np_settings_*` |
| Commercianti, negozi, abbinamenti BTCPay | Merchants, Stores | `np_merchants`, `np_stores`, `np_pairings`, `np_bps_users` |
| Token TTS, wallet | Tokens, Assets | `bolt_tokens*`, `np_wallets`, `np_assets`, `np_mpk` |
| Notifiche, log | Notifications, Log | `np_notifications*`, `np_log` |

In totale lo schema legacy ha 52 tabelle e 13.839 righe (TIP-019, backup del 2026-10-22).

## Proposta (fasi, ognuna con l'ok dell'utente)

1. **Copia legacy in sola lettura in locale.** Ripristino del backup del
   2026-10-22 in un DB separato `napay_legacy`, nel MySQL del sandbox napay.
   Utenti applicativi in sola lettura e nessun writer. Inventario di righe
   per tabella, colonne, chiavi e qualità dei dati. Mappa legacy → v2
   (documento `TIP-020/mapping.md`).
2. **Utenti e soci.** Riconciliazione `np_users` legacy ↔ `users` v2 per
   email: utenti già presenti in v2 conservati, quelli mancanti importati.
   Tipo socio, consensi e stato attivazione. Verifica che gli hash password
   legacy siano accettati dal login v2, così i soci non devono cambiare password.
3. **Migration schema v2** per quote, pagamenti, tipi di pagamento, verbali e
   cariche, più un comando di import dal legacy che si può rieseguire,
   idempotente, con conteggi e totali riconciliati per anno e tipo.
4. **Backoffice associazione**: lista soci con filtri, pagamenti con ricevuta
   PDF, stampa ed export, grafico, gestione quote, tipi, verbali e cariche.
   Ruoli: Amministratore e Segretario (il Segretario non modifica pagamenti
   né impostazioni).
5. **Pagamento quota** dentro l'app e da pagina pubblica, per chi entra da
   fuori. Integrazioni da rifare con API attuali:
   - PayPal: il vecchio SDK REST v1 e l'IPN vanno sostituiti da Checkout
     Orders v2 e webhook verificati;
   - Bitcoin: BTCPay Greenfield con webhook firmati, al posto della
     libreria v1 Bitpay;
   - contanti: registrazione manuale del pagamento dal backoffice.
6. **Transazioni dei commercianti** e il resto dei moduli `np_`, valutati dopo
   le fasi 1–5 in un TIP dedicato se il perimetro cresce.
7. **Cutover automatico** (decisione utente del 2026-11-11): nessun dump
   manuale. v2 legge il DB legacy all'avvio e migra in automatico, ripetendo
   l'import a ogni avvio finché la sorgente legacy è configurata. Lo
   spegnimento del vecchio sistema lo fa l'utente. Design e decisioni:
   [TIP-020/mapping.md](TIP-020/mapping.md).

## Criteri di accettazione

- Conteggi e totali importi per anno e tipo di pagamento identici tra legacy e v2.
- Ogni socio legacy è un utente v2 (email univoca) o compare in un report di scarti motivato.
- Un socio esistente accede con la password di sempre e vede lo storico delle sue quote.
- Pagamento quota PayPal e Bitcoin provato end-to-end in sandbox. Le notifiche
  senza firma valida vengono rifiutate e un webhook ripetuto non crea un
  pagamento doppio.
- La pagina di pagamento pubblica funziona senza passare dal menu dell'app.
- Il legacy resta in sola lettura e non viene mai modificato dall'import.

## Impatto

- `napay`: migration, model, controller e viste dell'associazione,
  componenti PayPal e BTCPay, comando di import.
- Sandbox locale: DB `napay_legacy` in sola lettura nel MySQL del sandbox.
- Segreti nuovi solo da env: credenziali PayPal, segreti webhook PayPal e BTCPay.

## Note implementative

- Produzione legacy servita in HTTP (browser: "Non sicuro"): password e
  pagamenti viaggiano in chiaro. Va messa in HTTPS o spenta il prima possibile,
  indipendentemente da questo TIP.
- Il backup contiene dati personali reali (soci, consensi, pagamenti): restano
  solo in locale, nessun dump nel repository o nei log.
- Le chiavi di cifratura legacy non sono state recuperate (TIP-019): eventuali
  campi cifrati si migrano così come sono, senza decifrarli.
- UI coerente con SIP-018 (Tabler).

## Log esecuzione

### Fase 1 - Copia legacy in sola lettura e inventario (COMPLETED, 2026-11-11)
- Backup datadir del 2026-10-22 recuperato con MySQL 8.0.46 in un volume
  temporaneo senza rete. Solo lo schema `napay` è importato come `napay_legacy`
  nel MySQL del sandbox. Volume e container temporanei sono stati rimossi.
- 52 tabelle e 13.839 righe: conteggi e `CHECKSUM TABLE EXTENDED` identici.
  Schema in `READ ONLY`, nessun grant all'utente dell'app.
- Inventario: [TIP-020/inventario-legacy.md](TIP-020/inventario-legacy.md).
  Bozza mappa: [TIP-020/mapping.md](TIP-020/mapping.md).
- **Il backup non è la produzione attuale**: pagamenti fino al 2022, mentre
  l'app online ha quote 2023–2026. Per riconciliazione e cutover serve un
  dump della produzione online.
- Segreti in chiaro in `np_settings_webapp` (PayPal, BTCPay, SSH, chiave sealer
  POA, ...): non si migrano nel DB, vanno ruotati.

### Passo 1 - Upgrade automatico del bootstrap (COMPLETED, 2026-11-11)
- Prerequisito: il bootstrap v2 bloccava l'app a ogni nuova migration.
- Ora, su un DB già ripristinato, le migration nuove vengono applicate all'avvio
  (`migrating`). Non c'è mai un reimport. Uno schema modificato a mano è
  rifiutato. Un upgrade fallito o interrotto viene ritentato e finché non
  riesce il web non parte.
- Commit napay `f9e21c72`. Test `tests/docker/bootstrap.sh`: 44 controlli verdi.
  Col codice precedente il test si ferma al primo upgrade.
