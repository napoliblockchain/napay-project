// Chain di sviluppo (solo locale): compila e pubblica TTSToken (sorgente: napoliblockchain/ttstoken).
// Rieseguibile: se il contratto registrato in /data/tts.json esiste sulla chain non fa nulla.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { JsonRpcProvider, Wallet, ContractFactory, Contract, isAddress, getAddress } from 'ethers';

const require = createRequire(import.meta.url);
const solc = require('solc');

const DATA = process.env.CHAIN_DATA_DIR || '/data';
const RPC = process.env.CHAIN_RPC_URL || 'http://besu:8545';
// token iniziali per i test (2 decimali): 1.000.000,00 TTS
// unità con 2 decimali: 100000000 = 1.000.000,00 TTS (TTS_MINT; TTS_DEV_MINT resta valido)
const MINT = BigInt(process.env.TTS_MINT || process.env.TTS_DEV_MINT || '100000000');

async function waitForChain(provider) {
    for (let i = 0; i < 90; i++) {
        try {
            const block = await provider.getBlockNumber();
            if (block > 0) return;
        } catch { /* nodo non ancora pronto */ }
        await new Promise((r) => setTimeout(r, 2000));
    }
    throw new Error(`chain non raggiungibile su ${RPC}`);
}

function compile() {
    const input = {
        language: 'Solidity',
        sources: { 'TTSToken.sol': { content: readFileSync(new URL('./contracts/TTSToken.sol', import.meta.url), 'utf8') } },
        settings: { optimizer: { enabled: false }, outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } } },
    };
    const findImports = (path) => {
        try {
            return { contents: readFileSync(require.resolve(path), 'utf8') };
        } catch {
            return { error: `import non trovato: ${path}` };
        }
    };
    const out = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
    const errors = (out.errors || []).filter((e) => e.severity === 'error');
    if (errors.length) throw new Error(errors.map((e) => e.formattedMessage).join('\n'));
    const c = out.contracts['TTSToken.sol'].TTSToken;
    return { abi: c.abi, bytecode: '0x' + c.evm.bytecode.object };
}

const provider = new JsonRpcProvider(RPC, Number(process.env.CHAIN_ID || 2118), { staticNetwork: true });
await waitForChain(provider);

if (existsSync(`${DATA}/tts.json`)) {
    const { address } = JSON.parse(readFileSync(`${DATA}/tts.json`, 'utf8'));
    if ((await provider.getCode(address)) !== '0x') {
        console.log(`[chain-deploy] TTSToken gia presente: ${address}`);
        process.exit(0);
    }
}

const { chainId } = await provider.getNetwork();
const deployer = new Wallet(readFileSync(`${DATA}/key`, 'utf8').trim(), provider);
// produzione: i token iniziali vanno al wallet indicato (TTS_RECIPIENT), non al validatore
const recipientEnv = (process.env.TTS_RECIPIENT || '').trim();
if (recipientEnv !== '' && !isAddress(recipientEnv)) {
    console.error('[chain-deploy] TTS_RECIPIENT non è un indirizzo valido');
    process.exit(1);
}
const recipient = recipientEnv === '' ? deployer.address : getAddress(recipientEnv);
const { abi, bytecode } = compile();

// transazioni legacy a gas zero, come la rete POA di produzione
const txOptions = { type: 0, gasPrice: 0n };
const token = await new ContractFactory(abi, bytecode, deployer).deploy(txOptions);
await token.waitForDeployment();
const address = await token.getAddress();
await (await new Contract(address, abi, deployer).mint(recipient, MINT, txOptions)).wait();

const info = {
    address,
    chainId: Number(chainId),
    rpc: RPC,
    symbol: 'TTS',
    decimals: 2,
    holder: recipient,
    minter: deployer.address,
};
writeFileSync(`${DATA}/tts.json`, JSON.stringify(info, null, 2));
console.log(`[chain-deploy] TTSToken pubblicato: ${address} (chainId ${info.chainId})`);
