# B1b - Via libera al codice (master, 2026-11-13)

Schema29134fa approvato per migration e test isolati. Timestamp riservato:
m261113_120000_create_btcpay_provisioning_schema. Nessun deploy sandbox.

- Approvato UNIQUE uq-btcpay-terminals-scope(id,store_id,merchant_id) per FK
  forte. Aggiunta in nuova migration, non cambio colonne C1. Verificatore C1
  puo ammettere solo questo indice con definizione esatta; altri drift negati.
- Nonce/wrapped_dek VARBINARY con CHECK lunghezze esatte, non BINARY che
  padding automatico rende incapace di rifiutare input troppo corti.
- Technical email esattamente CONCAT('m-',ref,'@btcpay-merchants.jamprojects.it').
- Stato synced richiede ID remoto; contatori/versioni non negativi, envelope
  coerente con stato, FK tenant/istanza e current unica come proposta.
- CLA implementa migration, compatibilita verificatore C1 e test SQL/GRANT
  solo su usa-e-getta. Isolare e ripristinare schema B1 nei probe distruttivi
  C1 senza disattivare foreign_key_checks o saltare copertura C1.
- Bootstrap/utenti reali/stack/worker al master dopo review. Nessun backfill,
  segreto reale, API o provisioning in questa consegna. Documentazione finale:
  solo handoff con commit/test/limiti, niente nuovo ciclo di proposta.
