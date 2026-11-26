# SIP-022 B1 - Piano del worker di provisioning (agente Napay, 2026-11-13)

- Stato: **piano da confermare dal master** (solo documento). Flussi, stati e
  regole restano quelli di [B1-PROPOSTA](B1-PROPOSTA.md) sezioni 3-6: qui
  solo la divisione in micro-step di codice con write set.
- Pezzi già integrati: schema B1b, `ProvisioningJobs` (B1c), `RetryPolicy`,
  `ProvisioningHttpClient`, `CredentialEnvelope` (B1a), ruoli DB (master).

## Micro-step

| # | Contenuto | File nuovi (write set) | Test (usa-e-getta) |
| --- | --- | --- | --- |
| W1 | Accesso ai mapping: account, credenziali, store/pos link. CAS su `version`/`lock_version`, cifratura e lettura con `CredentialEnvelope` (keyring iniettato), una sola `current` per tipo. Nessuna chiamata remota. | `components/btcpay/provisioning/ProvisioningStore.php` | DB reale con utente worker limitato: CAS, gare a due connessioni, busta in/out, nessuna DELETE. |
| W2 | Passi remoti puri, con client HTTP iniettato: account A / A-r / B / C, store, app POS, esattamente come le tabelle 3.1-3.2 (esiti, `in_flight`, nessun secondo POST per store/app, adozione del solo marker unico). | `components/btcpay/provisioning/steps/{MerchantAccountStep,StoreLinkStep,PosLinkStep}.php` | Client HTTP finto per ogni riga delle tabelle: 201/200, 422, 401/403, 429 con Retry-After, 5xx, esito ignoto, marker zero/uno/più. |
| W3 | Esecutore: `claim` -> ricontrollo tenant sotto lock (merchant qualificato R1, negozio del merchant, terminale del negozio) -> checkpoint -> passo -> esito (`succeed`/`retryLater`/`reconcile`/`fail`), Retry-After via `RetryPolicy`. Comando console `btcpay-provision/run` (`--once`, ciclo con attesa fino al primo lavoro dovuto). | `components/btcpay/provisioning/ProvisioningWorker.php`, `commands/BtcpayProvisionController.php` | DB reale + client finto: lease scaduta, crash dopo checkpoint, tenant cambiato, deferred non ripreso. |
| W4 | Accodamento nella stessa transazione della scrittura Napay (SQL esplicito, GRANT a colonna del web): creazione negozio -> `store_link`; creazione terminale C4 -> `pos_link`; attivazione merchant R3b -> `merchant_account` (punto di innesto del master). | modifiche a `StoresController` (mio da oggi) e `PosManagement::createTerminal` (C4, mio) | HTTP reale: rollback insieme, nessun lavoro duplicato, utente web limitato. |
| W5 | Regtest reale: merchant -> account -> store -> app su stack B0 usa-e-getta, ripresa dopo interruzione, 429 rispettato. | `tests/docker/btcpay-provisioning-regtest.sh` | Stack B0 usa-e-getta, nessun Internet. |

## Configurazione (dal bootstrap del master, mai dal web)

Origine BTCPay e CA, file della chiave provisioner (solo `cancreateuser`,
`canviewusers`), keyring KEK, `instance` = SHA-256 dell'origine; tutti come
secret file del solo worker. Il web non li vede.

## Fuori da questo piano

Rotazione/revoca chiavi (sezione 6, dopo W5), riconciliazione impostazioni
BTCPay legacy (master), deploy e servizio worker nello stack (master).
