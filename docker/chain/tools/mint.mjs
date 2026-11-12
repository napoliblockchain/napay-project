// Emette nuovi TTS verso un wallet (SIP-017): "caricare i token sul proprio wallet" dopo il deploy.
// Firma con la chiave del deployer/minter in /data/key (resta sulla VPS della chain).
// Uso: TTS_RECIPIENT=0x... TTS_AMOUNT=1000.00 node mint.mjs
import { readFileSync } from 'node:fs';
import { JsonRpcProvider, Wallet, Contract, isAddress, getAddress, parseUnits } from 'ethers';

const DATA = process.env.CHAIN_DATA_DIR || '/data';
const RPC = process.env.CHAIN_RPC_URL || 'http://besu:8545';
const recipient = (process.env.TTS_RECIPIENT || '').trim();
const amount = (process.env.TTS_AMOUNT || '').trim();

if (!isAddress(recipient)) {
    console.error('[chain-mint] TTS_RECIPIENT deve essere un indirizzo 0x valido');
    process.exit(1);
}
if (!/^\d{1,12}(\.\d{1,2})?$/.test(amount) || Number(amount) <= 0) {
    console.error('[chain-mint] TTS_AMOUNT deve essere un importo positivo con al massimo 2 decimali (es. 1000.00)');
    process.exit(1);
}

const { address } = JSON.parse(readFileSync(`${DATA}/tts.json`, 'utf8'));
const provider = new JsonRpcProvider(RPC, Number(process.env.CHAIN_ID || 2118), { staticNetwork: true });
const minter = new Wallet(readFileSync(`${DATA}/key`, 'utf8').trim(), provider);
const token = new Contract(address, [
    'function mint(address to, uint256 value) returns (bool)',
    'function balanceOf(address owner) view returns (uint256)',
], minter);

const units = parseUnits(amount, 2);
await (await token.mint(getAddress(recipient), units, { type: 0, gasPrice: 0n })).wait();
const balance = await token.balanceOf(getAddress(recipient));
console.log(`[chain-mint] emessi ${amount} TTS a ${getAddress(recipient)}; saldo ${(Number(balance) / 100).toFixed(2)} TTS`);
