# SIP-022 B0 - Istanza di test, identità tecnica, credenziali e verifiche (PROPOSTA)

- Autore: agente Napay. Data: 2026-11-12.
- Riferimenti: [SIP-022](../SIP-022-provisioning-merchant-store-pos-btcpay.md),
  [SIP-023](../SIP-023-profili-soci-merchant-operatori.md), SIP-020 fase 5c.
- Stato: proposta in review del master. Decisioni dell'utente del 2026-11-12:
  B0-1 regtest locale, B0-2 una chiave provisioner (P1), B0-3 sottodominio di
  `jamprojects.it`. B0-4 e B0-5 restano proposte.
  Nessun codice, nessuna chiamata di creazione verso BTCPay, nessuna migration.

## 1. Situazione rilevata (Napay v2, 2026-11-12)

- Creazione negozio (`StoresController::actionCreate`) usa ancora il flusso
  sincrono legacy: chiamata `createStore` dentro la transazione DB, con chiave
  e host letti dalla tabella `settings` (`btcpayApiKey`, `btcpayHost`).
  - Chiave in chiaro nel DB, condivisa da tutti i negozi.
  - Il client legacy (`components/btcpayserver/*`) **non** usa il proxy di
    uscita: nella sandbox locale non raggiunge BTCPay; in produzione
    scavalcherebbe l'allowlist.
  - Con `settings` vuoti la creazione si ferma con "Chiavi API BTCPAY Server
    non disponibili" (caso segnalato dall'utente).
- Il client della quota associativa (`components/payments/BTCPay.php`, 5c) ha
  già il trasporto corretto: proxy `PAYMENT_PROXY`, TLS verificato, niente
  redirect, timeout, protocollo limitato. Da riusare, non duplicare.
- Istanza di produzione `btcpayserver.napoliblockchain.it`: mainnet, BTCPay
  2.4.7, NBXplorer 2.6.21, Bitcoin Core 32.1, PostgreSQL 18.6 (inventario
  2026-11-12). Nessuna istanza di test disponibile.

## 2. Decisioni proposte

### B0-1. Istanza di test

| Opzione | Pro | Contro |
| --- | --- | --- |
| **A. BTCPay regtest locale in Docker (consigliata)** | gratis, nessun bitcoin reale, stesse versioni della produzione, si azzera a piacere | circa 1-1,5 GB RAM sul PC; va tenuta allineata alle versioni di produzione |
| B. Istanza testnet/signet su VPS | simile alla produzione | costo VPS, gestione in più |
| C. Store di prova sulla produzione mainnet | nessuna installazione | **da escludere**: utenti e store reali sul server di produzione, chiave con privilegi da amministratore in giro |

Proposta A, nell'orchestratore (area stack del master: file da assegnare):
- `bitcoind` regtest, `nbxplorer`, `postgres`, `btcpayserver` con le versioni
  della produzione; rete Docker interna, nessuna porta pubblicata;
- raggiunta da Napay come `https://btcpay.local` tramite il gateway (CA
  locale), allowlist del proxy di uscita estesa a quel nome. Niente HTTP in
  chiaro come scorciatoia;
- avvio separato dallo stack quotidiano (profilo dedicato), dati in un volume
  usa-e-getta; nessun segreto nel repository.

### B0-2. Modello delle credenziali

| Opzione | Come | Valutazione |
| --- | --- | --- |
| **P1 (consigliata)** | Una sola chiave "provisioner" con permessi server (crea utenti, crea store, aggiunge utenti agli store, crea app POS), solo nel worker. Store creati dal provisioner; utente del merchant aggiunto allo store come proprietario | un segreto da proteggere; nessuna chiave per merchant da custodire |
| P2 | P1 + una chiave generata per ogni utente merchant, usata per le operazioni sui suoi store | limita i danni per merchant, ma moltiplica i segreti da cifrare, ruotare e revocare |

- La chiave provisioner è **separata** da `BTCPAY_API_KEY` (quota associativa)
  e da qualsiasi chiave di fatturazione: file env privato del solo worker
  (`BTCPAY_PROVISIONER_*`), mai nel DB, nel browser, nel POS o nei log.
- `settings.btcpayApiKey` / `btcpayHost` non vengono riattivati: dopo B1 la
  creazione negozio non li legge più; la rimozione dei valori dal DB è una
  modifica da concordare (dati condivisi).
- Fatture BTC dei negozi dei merchant (incassi): fuori B0, richiedono un SIP
  di pagamento; P1 non presuppone che il provisioner emetta fatture.

### B0-3. Identità tecnica del merchant su BTCPay

- Email tecnica deterministica, legata al mapping e non all'email del titolare:
  `m-<identificativo casuale del mapping>@<dominio tecnico>`.
  - L'identificativo è casuale, generato da Napay e salvato nel mapping
    (non ID numerico, nome, partita IVA o email).
  - È anche la **chiave di riconciliazione**: dopo un timeout si cerca
    l'utente per email invece di ricrearlo.
- **Dominio tecnico (decisione dell'utente): sottodominio di `jamprojects.it`**,
  dominio dell'utente con DNS gestibile. Nome proposto
  `btcpay-merchants.jamprojects.it`, da confermare. Le caselle non servono se
  BTCPay non invia email (da verificare, sezione 3); in quel caso basta che il
  sottodominio resti riservato a questo uso.
- Password: casuale, lunga, generata dal worker e **non salvata**; il merchant
  non entra mai in BTCPay. Recupero eventuale solo da admin BTCPay.
- Nome store: descrizione del negozio + identificativo del mapping, così la
  riconciliazione non dipende da nomi uguali.

### B0-4. Store già esistenti (dati legacy)

`storesettings.bps_storeid` dei negozi importati punta a store creati dal
vecchio Napay sulla produzione. Proposta: nessuna adozione automatica.
Mapping in stato "legacy da riconciliare", verifica manuale (store esiste,
proprietario, app POS) e conferma esplicita prima di usarlo. Nessun DELETE.

### B0-5. Ruoli sullo store

Proposta: utente del merchant con ruolo proprietario sul proprio store;
provisioner unico altro membro. Nessun altro merchant aggiunto. Da verificare
sulla 2.4.7 quali ruoli esistono e cosa vede ciascuno.

## 3. Verifiche sull'istanza di test (prima di B1)

Esito da registrare in questo allegato, senza chiavi, password o dump.

1. Versione e contratto: `/api/v1/health`, versione dal footer/`server/info`,
   copia di `/swagger/v1/swagger.json` (solo il file pubblico).
2. Policy del server: registrazione aperta/chiusa, conferma email obbligatoria,
   approvazione utenti, creazione store da non-admin, server email assente.
3. Utente creato dal provisioner con password: confermato? approvato? può
   avere store e API key? Parte qualche email?
4. Permessi minimi della chiave provisioner: tabella operazione -> permesso
   effettivamente richiesto (utente, store, membri store, app POS, letture di
   riconciliazione). Ogni permesso superfluo tolto e ricontrollato.
5. Proprietà: due merchant di test, due store; ognuno vede solo il proprio;
   il provisioner resta membro; nessun accesso incrociato.
6. App POS: creazione sullo store mappato, campi minimi, lettura per
   riconciliazione.
7. Riconciliazione dopo timeout: utente trovato per email tecnica, store e
   app trovati tramite identificativo nel nome; POST ripetuto senza
   riconciliazione = duplicato (atteso), quindi vietato nel worker.
8. Errori: chiave errata/revocata, permesso mancante, BTCPay spento, 404, 429
   (se presente): codici e forme delle risposte per il worker.
9. Trasporto: tutte le chiamate tramite il proxy di uscita con TLS verificato,
   come il client 5c; nessuna uscita diretta.

## 4. Consegna di B0

- Questo allegato aggiornato con esiti e scelte definitive.
- Elenco file per B1 da riservare (mapping/outbox/worker, migration con
  timestamp del master) e modifiche condivise richieste (StoresController,
  MerchantsController, egress, stack di test).
- Nessun codice di provisioning fino all'approvazione di B0.

## 5. Richieste

All'utente:
- Conferma del nome del sottodominio (`btcpay-merchants.jamprojects.it`).
- B0-4: store legacy solo con riconciliazione manuale (proposta).

Al master:
- Assegnazione dei file dello stack di test BTCPay (compose, gateway
  `btcpay.local`, allowlist egress) oppure realizzazione a cura del master.
- Review di questa proposta e ordine rispetto agli inviti C4.
