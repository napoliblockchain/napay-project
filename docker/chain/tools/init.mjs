// Genera chiave del validatore e genesis QBFT a nodo singolo (sviluppo locale e produzione, SIP-023).
// Le chiavi sono create al primo avvio dentro il volume /data e non vanno mai nel repository.
// Rieseguibile: se il genesis esiste gia non fa nulla.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { Wallet, encodeRlp, ZeroHash, parseEther, toBeHex } from 'ethers';

const DATA = process.env.CHAIN_DATA_DIR || '/data';
const CHAIN_ID = Number(process.env.CHAIN_ID || 2118);
const BLOCK_PERIOD = Number(process.env.CHAIN_BLOCK_PERIOD || 2);
// produzione: account faucet separato per il gas dei wallet (la chiave del validatore non esce mai dalla VPS)
const FAUCET = process.env.CHAIN_FAUCET === '1';

if (!Number.isInteger(CHAIN_ID) || CHAIN_ID < 1 || !Number.isInteger(BLOCK_PERIOD) || BLOCK_PERIOD < 1) {
    console.error('[chain-init] CHAIN_ID e CHAIN_BLOCK_PERIOD devono essere interi positivi');
    process.exit(1);
}

if (existsSync(`${DATA}/genesis.json`)) {
    console.log('[chain-init] genesis gia presente, nessuna azione');
    process.exit(0);
}
mkdirSync(DATA, { recursive: true });

// validatore unico: firma i blocchi ed e anche l'account finanziato per deploy e test
const validator = Wallet.createRandom();
const faucet = FAUCET ? Wallet.createRandom() : null;

// extraData QBFT: RLP([vanity 32 byte, [validatori], voti vuoti, round 0, sigilli vuoti])
const extraData = encodeRlp([ZeroHash, [validator.address], [], '0x', []]);

const genesis = {
    config: {
        chainId: CHAIN_ID,
        berlinBlock: 0,
        londonBlock: 0,
        zeroBaseFee: true,
        qbft: { blockperiodseconds: BLOCK_PERIOD, epochlength: 30000, requesttimeoutseconds: BLOCK_PERIOD * 2 },
    },
    nonce: '0x0',
    timestamp: '0x0',
    gasLimit: '0x1fffffffffffff',
    difficulty: '0x1',
    mixHash: '0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365',
    coinbase: '0x0000000000000000000000000000000000000000',
    alloc: {
        [validator.address]: { balance: toBeHex(parseEther('1000000')) },
        ...(faucet ? { [faucet.address]: { balance: toBeHex(parseEther('1000000')) } } : {}),
    },
    extraData,
};

writeFileSync(`${DATA}/genesis.json`, JSON.stringify(genesis, null, 2));
writeFileSync(`${DATA}/key`, validator.privateKey, { mode: 0o600 });
if (faucet) writeFileSync(`${DATA}/faucet-key`, faucet.privateKey, { mode: 0o600 });
writeFileSync(`${DATA}/accounts.json`, JSON.stringify({ validator: validator.address, ...(faucet ? { faucet: faucet.address } : {}) }, null, 2));
console.log(`[chain-init] genesis QBFT creato: chainId ${CHAIN_ID}, validatore ${validator.address}`);
