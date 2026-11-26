# SIP-020 - Inventario schema legacy `napay`

Fonte: backup datadir locale `/home/sergio/backup-mysql-datadir-2026-10-22.tgz`
(MySQL 8.0.46), schema `napay`. Recuperato il 2026-11-11 come `napay_legacy`
nel MySQL 8.4.13 del sandbox napay. Il documento contiene solo struttura e
aggregati, nessun dato personale.

## Copia locale

- Recupero in un volume temporaneo senza rete, con MySQL avviato senza grant
  e con binlog ed eventi spenti. Dump in pipe dentro `napay_legacy`, senza file
  intermedi. Volume e container temporanei rimossi a fine operazione.
- Viene estratto solo lo schema `napay`. Gli altri schemi presenti nel backup
  (altri progetti) non vengono copiati.
- Verifica: 52 tabelle e 13.839 righe, conteggi esatti per tabella identici,
  `CHECKSUM TABLE ... EXTENDED` identico per tutte le tabelle.
- Nessuna vista, trigger, routine o evento. Nessuna foreign key dichiarata:
  le relazioni sono solo applicative.
- `ALTER SCHEMA napay_legacy READ ONLY = 1`. L'utente dell'app `napay_browser`
  non ha grant su `napay_legacy`: legge solo root.

## Attenzione: il backup NON è la produzione attuale

`st_pagamenti` arriva al 2022 (ultima scadenza 2022-12-31), mentre l'app
online `napay.napoliblockchain.it` (verifica utente del 2026-11-11) mostra
quote con scadenza 2023, 2024 e un pagamento in corso al 2026-11-11.
Mappa e import si possono preparare su questa copia, ma la riconciliazione
finale e il cutover richiedono un **dump della produzione online**.

## Aggregati dell'associazione

Soci (`np_users`: 56 utenti, nessuna email duplicata):

| Tipo utente | Attivi | Righe |
| --- | ---: | ---: |
| Socio | 41 | 41 |
| Commerciante | 12 | 12 |
| Amministratore | 3 | 3 |

- Gli hash password sono tutti bcrypt `$2y$` (60 caratteri, 56 su 56):
  compatibili con la verifica password di Yii2, quindi i soci non dovrebbero
  doverle reimpostare. Da confermare con una prova nella fase 2.
- Una sola email legacy è presente anche fra gli utenti v2 del sandbox.
- Colonna `ga_secret_key` (2FA Google Authenticator): segreto, da decidere se
  migrarlo.

Tipi di pagamento (`st_tipo_pagamenti`): Bitcoin, Paypal, Token, Bonifico,
Contanti, Esente. Quote (`st_quote`): annuale 20 €, Donazione, Esente.
Tipi utente (`np_users_type`): POS, Commerciante, Amministratore, Socio, Istituto.

Pagamenti (`st_pagamenti`: 91 righe, tutte con un utente esistente):

| Tipo | Stato | N | Totale € | Dal | Al |
| --- | --- | ---: | ---: | --- | --- |
| Bitcoin | expired | 7 | 170 | 2019-06-04 | 2020-05-25 |
| Bitcoin | new | 9 | 390 | 2020-11-16 | 2021-04-19 |
| Bitcoin | paid | 1 | 20 | 2020-07-07 | 2020-07-07 |
| Contanti | paid | 17 | 520 | 2019-03-19 | 2020-02-05 |
| Esente | paid | 2 | 0 | 2019-07-08 | 2020-02-04 |
| Paypal | invalid | 3 | 0 | 2019-06-04 | 2021-03-18 |
| Paypal | new | 15 | 540 | 2019-06-04 | 2022-06-20 |
| Paypal | paid | 37 | 870,10 | 2019-06-06 | 2022-06-13 |

Per anno di registrazione: 2019 38 (1.160,10 €), 2020 32 (920 €), 2021 17 (350 €), 2022 4 (80 €).
`importo` è di tipo `float` (il totale PayPal risulta 870.1000000014901): in v2 va usato `DECIMAL`.

Transazioni dei commercianti (`np_transactions`: 131 righe, 2019-06 → 2020-07):
32 complete, 95 expired, 3 new, 1 invalid. Verbali: 3 (2019-07 → 2020-01).

## Tabelle

20 tabelle su 52 sono MyISAM. Le collation sono utf8mb3, a parte
`dali_stradario` (utf8mb4) e `migration` (latin1).

| Tabella | Righe | Motore | Collation | Colonne |
| --- | ---: | --- | --- | ---: |
| `bolt_contacts` | 140 | InnoDB | utf8mb3_general_ci | 3 |
| `bolt_settings_user` | 126 | MyISAM | utf8mb3_general_ci | 4 |
| `bolt_socialusers` | 58 | InnoDB | utf8mb3_unicode_ci | 9 |
| `bolt_tokens` | 0 | MyISAM | utf8mb3_general_ci | 17 |
| `bolt_tokens_memo` | 0 | InnoDB | utf8mb3_general_ci | 3 |
| `bolt_users` | 63 | MyISAM | utf8mb3_general_ci | 8 |
| `bolt_vapid_subscription` | 8 | MyISAM | utf8mb3_general_ci | 7 |
| `bolt_wallets` | 51 | MyISAM | utf8mb3_general_ci | 4 |
| `dali_archive` | 0 | InnoDB | utf8mb3_general_ci | 20 |
| `dali_quartieri` | 30 | InnoDB | utf8mb3_general_ci | 2 |
| `dali_stradario` | 3848 | InnoDB | utf8mb4_0900_ai_ci | 7 |
| `dali_users` | 36 | InnoDB | utf8mb3_general_ci | 7 |
| `migration` | 1 | InnoDB | latin1_swedish_ci | 2 |
| `np_assets` | 2 | MyISAM | utf8mb3_general_ci | 3 |
| `np_associations` | 1 | InnoDB | utf8mb3_general_ci | 9 |
| `np_bills` | 0 | InnoDB | utf8mb3_general_ci | 10 |
| `np_blockchains` | 2 | MyISAM | utf8mb3_general_ci | 5 |
| `np_bps_users` | 12 | InnoDB | utf8mb3_general_ci | 3 |
| `np_comuni_italiani` | 7926 | InnoDB | utf8mb3_general_ci | 4 |
| `np_consensus` | 0 | MyISAM | utf8mb3_general_ci | 5 |
| `np_exchanges` | 5 | InnoDB | utf8mb3_general_ci | 2 |
| `np_gateways` | 4 | InnoDB | utf8mb3_general_ci | 3 |
| `np_institutes` | 0 | MyISAM | utf8mb3_general_ci | 9 |
| `np_log` | 0 | MyISAM | utf8mb3_bin | 10 |
| `np_merchants` | 12 | InnoDB | utf8mb3_general_ci | 9 |
| `np_mpk` | 9 | MyISAM | utf8mb3_general_ci | 6 |
| `np_nodes` | 1 | MyISAM | utf8mb3_general_ci | 3 |
| `np_notifications` | 59 | InnoDB | utf8mb3_general_ci | 10 |
| `np_notifications_readers` | 125 | InnoDB | utf8mb3_general_ci | 4 |
| `np_pairings` | 10 | InnoDB | utf8mb3_general_ci | 5 |
| `np_pos` | 13 | InnoDB | utf8mb3_general_ci | 6 |
| `np_pos_invoices` | 5 | MyISAM | utf8mb3_general_ci | 16 |
| `np_pos_invoices_memo` | 5 | MyISAM | utf8mb3_general_ci | 3 |
| `np_products` | 10 | MyISAM | utf8mb3_general_ci | 8 |
| `np_settings_shops` | 0 | MyISAM | utf8mb3_general_ci | 4 |
| `np_settings_stores` | 432 | MyISAM | utf8mb3_general_ci | 4 |
| `np_settings_user` | 430 | InnoDB | utf8mb3_general_ci | 4 |
| `np_settings_webapp` | 67 | InnoDB | utf8mb3_general_ci | 3 |
| `np_shops` | 0 | MyISAM | utf8mb3_general_ci | 6 |
| `np_stores` | 14 | InnoDB | utf8mb3_general_ci | 10 |
| `np_transactions` | 131 | InnoDB | utf8mb3_general_ci | 20 |
| `np_transactions_data` | 0 | MyISAM | utf8mb3_general_ci | 9 |
| `np_transactions_info` | 22 | MyISAM | utf8mb3_general_ci | 14 |
| `np_users` | 56 | InnoDB | utf8mb3_general_ci | 17 |
| `np_users_type` | 5 | InnoDB | utf8mb3_general_ci | 4 |
| `np_vapid_subscription_da_cancellare` | 5 | InnoDB | utf8mb3_general_ci | 7 |
| `np_wallets` | 4 | InnoDB | utf8mb3_general_ci | 4 |
| `st_cariche` | 8 | InnoDB | utf8mb3_general_ci | 3 |
| `st_pagamenti` | 91 | InnoDB | utf8mb3_general_ci | 13 |
| `st_quote` | 3 | InnoDB | utf8mb3_general_ci | 4 |
| `st_tipo_pagamenti` | 6 | InnoDB | utf8mb3_general_ci | 3 |
| `st_verbali` | 3 | InnoDB | utf8mb3_general_ci | 4 |
