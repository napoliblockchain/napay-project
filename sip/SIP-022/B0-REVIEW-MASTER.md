# SIP-022 B0 - Review e assegnazione master

Data: 2026-11-12. Proposta revisionata: `2988c52`, `6b8fd48`.

## Esito e decisioni

Approvata la preparazione dello stack e delle verifiche B0, non il provisioning B1.
Decisioni dell'utente confermate:

- BTCPay regtest locale, nessun collegamento alla produzione per i test.
- P1: una chiave provisioner separata dalle quote associative, disponibile solo
  al futuro worker, non a web/POS. Permessi minimi da dimostrare sull'istanza.
- Identita tecniche su `btcpay-merchants.jamprojects.it`, senza email personali.
  Nessuna casella o modifica DNS necessaria in questo micro-step locale.
- Store legacy: riconciliazione e approvazione esplicita prima del riuso,
  niente adozione automatica, cancellazioni o modifiche remote.
- Ruolo proprietario per l'utente tecnico del merchant: approvato come obiettivo
  di test B0-5; efficacia e isolamento da verificare prima di B1.

## Correzioni e gate B0

1. Versioni citate nella proposta = inventario dichiarato dall'agente, non
   verifica del master. Verificare tag reali, disponibilita e compatibilita;
   fissare immagini/digest, non `latest`. Non interrogare la produzione.
2. Scaricare OpenAPI dall'istanza regtest: versione/plugin determinano il
   contratto effettivo. Registrare matrice endpoint/permesso/esito; niente
   chiave `unrestricted` come soluzione definitiva senza escalation esplicita.
3. Creazione utente con password casuale e invito email disattivato se il
   contratto dell'istanza lo supporta. Nessuna password persistita/loggata;
   verificare che recupero password o email server non apra accessi indesiderati.
4. Riconciliazione: un identificativo nel nome non e un vincolo di unicita
   remoto. Dopo timeout, risultati multipli o non conclusivi = stato ambiguo,
   nessun nuovo POST automatico. B1 richiedera outbox/mapping locale univoci,
   serializzazione per risorsa e recovery dimostrato, non solo ricerca per nome.
5. HTTP backend interno al reverse proxy non sostituisce HTTPS del client:
   Napay/worker passano dal proxy egress a `https://btcpay.local`, CA verificata,
   senza redirect. Allowlist esatta host:443, non wildcard o intere reti private.
6. Stack opt-in, nessuna porta host per DB/RPC/UI, rete distinta da POS e DB
   Napay, healthcheck/readiness e tempi massimi. Dati test in volume nominato,
   conservati ai normali stop; reset distruttivo solo comando esplicito.

Riferimenti ufficiali verificati il 2026-11-12:
[integrazione Greenfield](https://docs.btcpayserver.org/Developers/api/),
[API Greenfield](https://docs.btcpayserver.org/API/Greenfield/v1/),
[autorizzazione](https://docs.btcpayserver.org/BTCPayServer/greenfield-authorization/).
Questi riferimenti non sostituiscono le prove sulla versione regtest fissata.

## Assegnazione stack

Responsabile: agente Napay, in worktree/branch orchestratore separato
`feature/btcpay-regtest-b0`, dopo le correzioni C4 prioritarie.
Write set esclusivo:

- `docker/btcpay-regtest/compose.yml`, `local.sh`, `.env.example`, `README.md`;
- `docker/btcpay-regtest/tests/*`;
- `sip/SIP-022/B0-ESITI.md` e `B0-HANDOFF.md`.

Solo questi file nuovi. Riutilizzare convenzioni locali per segreti, controlli
percorso/proprietario/permessi e avvio senza duplicare gateway o stack quotidiano.
Stato privato configurabile con `BTCPAY_LOCAL_STATE`, assoluto e fuori repo;
convenzione `/var/www/documents/progetti/napoliblockchain/btcpay/ambiente-locale/`,
0700/0600 e `.gitignore` locale. Non committare segreti o dump.

Il master riserva e integra i file condivisi: `docker-compose.yml`,
`docker/compose/infra.yml`, `docker/gateway/conf.d/btcpay.caddy`,
`start-localhost.sh`, egress/configurazione Napay. L'agente consegna patch
proposte in B0-HANDOFF, non modifica questi file e non riavvia il gateway.
Nessuna modifica a `StoresController`, `MerchantsController`, tabelle legacy,
settings, API quote o provisioning. Nessuna chiave produzione.

Prima consegna: compose validato, healthcheck, test isolati e patch di rete/CA/
allowlist. Poi il master integra e autorizza avvio condiviso e verifiche via TLS.
B1 resta bloccato fino a esiti B0 approvati; nessun timestamp migration B1 assegnato.
