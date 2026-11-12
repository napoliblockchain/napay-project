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
- Rete `btcpay_regtest_edge` (interna, subnet fissa `10.252.0.0/24`, creata da
  `local.sh` se manca): solo `btcpayserver` e il gateway. Una rete omonima
  diversa (non interna, altra etichetta o subnet) non viene riusata né toccata.
- Rete `btcpay_regtest_client` (integrazione del master): solo gateway, con alias
  `btcpay.local` e CA locale, e proxy di uscita Napay. Il proxy non entra mai
  nella rete edge; il gateway rifiuta la subnet edge su tutti i siti.
- Napay e il futuro worker arrivano solo tramite il proxy di uscita
  (allowlist `btcpay.local:443`), mai in HTTP diretto.
- Segreti (password PostgreSQL e stringhe di connessione) in
  `$BTCPAY_LOCAL_STATE/regtest.env`, 0600; cartella 0700 con `.gitignore` `*`.
- `BTCPAY_LOCAL_STATE` deve essere un percorso canonico (niente `..` o symlink)
  fuori dai checkout; file privati verificati prima di aprirli, mai sovrascritti.

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
bash docker/btcpay-regtest/tests/filesystem.sh   # local.sh, senza Docker reale
bash docker/btcpay-regtest/tests/isolated.sh     # stack reale, risorse temporanee
bash docker/btcpay-regtest/tests/topology.sh     # topologia gateway/proxy proposta
```

Solo risorse temporanee e sentinelle locali, mai Internet o produzione; ogni
controllo negativo ha il suo controllo positivo. Dettagli in
`sip/SIP-022/B0-ESITI.md`.
