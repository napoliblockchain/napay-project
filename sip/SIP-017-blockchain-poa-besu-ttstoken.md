# SIP-017 - Blockchain POA: Hyperledger Besu + TTS Token

- Stato: OPEN
- Area: Blockchain Infrastructure
- Repo: `ttstoken` (https://github.com/napoliblockchain/ttstoken.git)
- Branch target: n/a (infrastruttura separata)
- Segnalato: 2026-05-15

## Contesto

poawallet opera su una blockchain privata Proof-of-Authority (POA) basata su Hyperledger Besu con consenso IBFT 2.0.
Il token nativo della piattaforma e il TTS Token (ERC20), deployato su questa chain con Truffle.
L'infrastruttura blockchain viene installata su una **VPS separata** rispetto alle webapp Napay.

La guida di riferimento originale e in `/var/www/documents/blockchain/Fidelity POA.md`.

## Parametri blockchain

| Parametro | Valore |
| -- | -- |
| chainId | 2118 |
| Consenso | IBFT 2.0 (Hyperledger Besu) |
| Block period | 30 secondi |
| Epoch length | 30000 |
| Request timeout | 10 secondi |
| Tool setup | `npx quorum-dev-quickstart` |

### Endpoint di rete (riferimento istanza Fidelity)

| Servizio | Endpoint |
| -- | -- |
| JSON-RPC HTTP | http://167.86.80.222:8545 |
| JSON-RPC WebSocket | ws://167.86.80.222:8546 |
| Block explorer | http://167.86.80.222:25000/ |
| Prometheus | http://167.86.80.222:9090/graph |
| Grafana | http://167.86.80.222:3000 |

> Questi endpoint sono dell'istanza storica (fid3lize.tk). Per una nuova VPS i valori cambieranno.

### Sealers (3 validatori)

I sealers sono gli account che firmano i blocchi nella POA. Generati con `npx quorum-dev-quickstart`.
Le chiavi private dei sealers NON vanno nel repository.

## TTS Token

- Repo: https://github.com/napoliblockchain/ttstoken.git
- Linguaggio contratto: Solidity + Vyper
- Standard: ERC20 con 2 decimali (supply configurabile in `contracts/TTSToken.sol`)
- Tool: Truffle + truffle-privatekey-provider + @openzeppelin/contracts@2.4.0

### Setup deploy

```bash
git clone https://github.com/napoliblockchain/ttstoken.git
cd ttstoken

# Se si e' root
npm config set user 0
npm config set unsafe-perm true

npm install -g truffle
npm install truffle-privatekey-provider @openzeppelin/contracts@2.4.0
npm install

pip3 install vyper
```

Modificare `truffle-config.js` con `privateKey` e `providerUrl` della VPS target.

Modificare supply in `contracts/TTSToken.sol`:
- `1e9` = 10.000.000,00 con 2 decimali
- `1e24` = 1.000.000.000.000.000,000000000 con 9 decimali

```bash
truffle compile
truffle migrate --network private --skipDryRun
```

## Setup VPS blockchain (nuovo deployment)

### Prerequisiti

```bash
apt install docker.io python3-pip
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs
```

> La guida originale usa Node 12.x ma per nuovo deployment preferire Node 18 LTS.

### Generazione rete

```bash
npx quorum-dev-quickstart
# Scegliere: Hyperledger Besu, no Orchestrate, no private tx, no logging
# Output in: ./quorum-network
./run.sh
```

### Configurazione genesis (ibft2genesis.json)

Impostare `chainId: 2118` e `blockperiodseconds: 30`.
Aggiungere indirizzi sealers e balance iniziale in `alloc`.

## Relazione con poawallet

poawallet si connette alla blockchain POA tramite:
- `config/params.php`: parametro `WebSocketServerAddress` punta al nodo Besu WS
- Model `Blockchains`: chainId, rpc url, ws url per ogni chain configurata
- Model `Nodes`: elenco nodi per chain
- `components/Erc20.php`: interazione contratti ERC20 (TTS Token incluso)

In ambiente Docker (Step 1.5) la connessione al nodo Besu sara configurata via env var.

## Rischi

- La VPS blockchain e separata: failover e backup sealers vanno pianificati.
- Le chiavi private dei sealers sono critiche: perderle significa perdere il consenso.
- Il token TTS e la chain sono accoppiati: upgrade contratto richiede migrazione balance.

## Prossimi passi

- [ ] Definire VPS target per nuova installazione Besu
- [ ] Generare nuovi sealers (non usare le chiavi dell'istanza Fidelity in produzione)
- [ ] Documentare indirizzo contratto TTS Token deployato
- [ ] Collegare poawallet alla nuova chain tramite pannello admin Blockchains/Nodes

## Chain di sviluppo locale (2026-10-23)

Per testare il wallet senza VPS: profilo compose `chain` in `docker/compose/wallet.yml`.

- `chain-init`: al primo avvio genera chiave del validatore e genesis QBFT a nodo singolo (chainId 2118, gas zero, blocco ogni 2s) nel volume `chain_data`. Nessuna chiave nel repository.
- `besu`: `hyperledger/besu:26.9.0`, utente uid 1000, RPC solo su rete interna (`http://besu:8545`), niente discovery, `--sync-min-peers=0`.
- `chain-deploy`: compila TTSToken (sorgente `napoliblockchain/ttstoken`, solc 0.5.17 + OpenZeppelin 2.4.0 come in produzione) e lo pubblica; indirizzo in `/data/tts.json`. Rieseguibile.
- Avvio: `docker compose --profile chain up -d chain-init besu chain-deploy`.
- `npm audit` degli strumenti: advisory su OpenZeppelin 2.4.0 (GHSA-88g8 Initializable, GHSA-7grf ERC165Checker): non si applicano, TTSToken non usa quei moduli. `tmp` forzato a `^0.2.7` (override), resta pulito.
- Test di integrazione poawallet: `tests/chain/erc20-integration.php` (13 controlli su `Erc20`: blocchi, nonce, saldi, stima gas, invio token firmato, faucet gas), riferimento per la sostituzione di `sc0vu/web3.php`.
- Le chiavi private Besu nei documenti di `napay-docs` sono state rimosse (commit `77e51a1`): restano nella storia pubblica, considerarle compromesse.

## Chain di produzione (2026-11-12)

Decisioni dell'utente:

- Chain nuova da zero: nuovo genesis, nuovo contratto TTS, nessun saldo migrato.
- chainId **2118** condiviso con il progetto Fidelity: una sola POA servira entrambi.
  Ogni progetto ha il proprio account faucet e i propri contratti.
- VPS dedicata alla chain, separata dalle app; collegamento tramite firewall e
  TLS, niente VPN.
- Consenso QBFT (sostituisce IBFT 2.0 della vecchia istanza), un validatore;
  altri validatori solo se servira tolleranza ai guasti.

Implementazione: `docker/chain/prod/compose.yml` (orchestratore).

- `besu` (26.9.0) su rete Docker interna, senza porte pubblicate e senza uscita
  internet; RPC solo `ETH,NET,WEB3`; `--host-allowlist` limitato al dominio
  pubblico; limite memoria e heap JVM configurabili; `cap_drop: ALL`.
- `caddy` (2.8.4) unico ingresso: 80/443 aperte per Let's Encrypt, JSON-RPC
  accettato solo in POST e solo dagli IP in `RPC_ALLOWED_IPS` (app napay e
  Fidelity); per tutti gli altri la connessione viene chiusa.
- `tools`, solo a riga di comando:
  - `init.mjs` con `CHAIN_FAUCET=1`: chiave del validatore, account faucet
    separato (gas dei wallet), genesis con `CHAIN_BLOCK_PERIOD`;
  - `deploy.mjs` con `TTS_RECIPIENT`: emissione iniziale (`TTS_MINT`) sul wallet
    indicato, il validatore resta minter;
  - `mint.mjs` con `TTS_RECIPIENT` e `TTS_AMOUNT`: nuove emissioni verso un wallet.
- Chiavi (validatore e faucet) generate sulla VPS nel volume `chain_data`: mai
  nei repository; backup cifrato fuori macchina.
- Configurazione non segreta in `.env` accanto al compose (`.env.example`).
- Procedura operativa con indirizzi e IP: documentazione privata.

Verifica (stack completo in locale, porte non pubblicate): genesis con faucet,
deploy con destinatario, mint 10,25 TTS, `eth_chainId` 200 dall'IP ammesso,
connessione chiusa da IP non ammesso e per richieste GET, besu senza uscita
internet, limite memoria applicato.

Prossimi passi produzione:

- [ ] Pulizia della VPS chain e firewall host (22, 80, 443)
- [ ] Record DNS del dominio RPC, `.env`, avvio, deploy TTS con destinatario
- [ ] Faucet napay nel `.env` del wallet; nodo RPC nel pannello Blockchains/Nodes
- [ ] Backup cifrato di `chain_data` fuori macchina, verifica del ripristino
- [ ] Fidelity: proprio faucet e contratti sulla stessa chain (attivita separata)
