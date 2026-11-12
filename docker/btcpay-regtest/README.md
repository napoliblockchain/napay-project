# BTCPay Server regtest locale (SIP-022 B0)

Istanza BTCPay con bitcoin finti (regtest), solo per verificare il provisioning
di merchant, negozi e app POS. Mai collegata alla produzione.

## Componenti

| Servizio | Immagine (fissata per digest nel compose) | Note |
| --- | --- | --- |
| `postgres` | `postgres:18.6` | database di BTCPay e NBXplorer |
| `bitcoind` | `btcpayserver/bitcoin:32.1` | regtest, RPC e P2P solo sulla rete interna |
| `nbxplorer` | `nicolasdorier/nbxplorer:2.6.21` | indicizzatore, senza autenticazione ma solo interno |
| `btcpayserver` | `btcpayserver/btcpayserver:2.4.7` | API Greenfield su `btcpay-regtest:49392` |

Tag uguali all'inventario dichiarato della produzione (2026-11-12). Prima di
aggiornare: verificare i tag reali, fissare i nuovi digest, rieseguire i test.

## Rete e sicurezza

- Nessuna porta sull'host. Rete `regtest` interna: nessun container esce su internet.
- Rete `btcpay_regtest_edge` (interna, creata da `local.sh`): solo `btcpayserver`
  e, dopo l'integrazione del master, il gateway (`https://btcpay.local`, CA locale).
- Napay e il futuro worker arrivano solo tramite il proxy di uscita
  (allowlist `btcpay.local:443`), mai in HTTP diretto.
- Segreti (password PostgreSQL e stringhe di connessione) in
  `$BTCPAY_LOCAL_STATE/regtest.env`, 0600; cartella 0700 con `.gitignore` `*`.

## Uso

```bash
export BTCPAY_LOCAL_STATE=/var/www/documents/progetti/napoliblockchain/btcpay/ambiente-locale
bash docker/btcpay-regtest/local.sh up       # avvia; al primo avvio crea segreti e mina 101 blocchi
bash docker/btcpay-regtest/local.sh status
bash docker/btcpay-regtest/local.sh stop     # ferma, dati conservati
bash docker/btcpay-regtest/local.sh reset --yes   # cancella i dati di test (unico comando distruttivo)
```

In alternativa le variabili in `docker/btcpay-regtest/.env` (vedi `.env.example`).
Lo stack è separato da `start-localhost.sh` e non si avvia con lo stack quotidiano.

## Test

```bash
bash docker/btcpay-regtest/tests/isolated.sh
```

Progetto, rete e cartella privata temporanei; pulisce solo le proprie risorse.
Verifica: avvio sano, nessuna porta, digest, permessi dei segreti, health
sincronizzato, OpenAPI non pubblica, nessuna uscita internet, RPC del nodo non
raggiungibile dalla rete edge, persistenza dopo stop/up, reset solo con `--yes`.
