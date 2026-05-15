# TIP-017 - Blockchain POA: Hyperledger Besu + TTS Token

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
