# SIP-032 - Wallet: una rete e un token dalle variabili d'ambiente

- Stato: IN SVILUPPO (passi 1 e 2 fatti 2026-11-16)
- Area: Wallet / Blockchain / Sicurezza
- Repo: `poawallet`, `napay-project` (compose, launcher)
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-16

## Contesto

Il wallet nasceva multi-rete: ogni utente aveva la sua rete (URL RPC, chain id,
explorer), il suo token (indirizzo, decimali, simbolo, ABI) e un "nodo" che li
collegava, gestiti dalle pagine "Select nodes", "Manage tokens", "Manage
networks". Il wallet servirà solo Napay: una chain e un token. L'URL RPC scelto
dall'utente era anche un rischio SSRF (il server chiamava l'indirizzo indicato).

## Decisione utente (2026-11-16)

Configurazione nelle variabili d'ambiente, non nell'app; nel wallet resta solo
"Network info". Le righe per utente vanno tolte prima della versione definitiva
(il database di produzione partirà vuoto).

## Passi

1. **Configurazione dalle variabili** (fatto, poawallet `54b264d`, orchestratore
   `79887a7`): `ChainConfig` valida `CHAIN_RPC_URL`, `CHAIN_ID`, `CHAIN_NAME`,
   `CHAIN_SYMBOL`, `CHAIN_EXPLORER_URL`, `CHAIN_ZERO_GAS`, `TTS_TOKEN_ADDRESS`,
   `TTS_TOKEN_NAME`, `TTS_TOKEN_SYMBOL`, `TTS_TOKEN_DECIMALS`; ABI ERC-20 nel
   codice; tutto il codice legge da lì. Il launcher passa l'indirizzo del token.
2. **Rimozione di pagine e righe per utente** (fatto, poawallet `9c10da4`,
   orchestratore `c4553a4`): controller, viste e modelli di nodi, reti, token,
   tipi di contratto, valori standard, Settings e `wallet/rescan`; wizard e
   ripristino non creano più righe; menu con solo "Network info" (senza URL
   RPC interno); indicizzatore Go con il token dalle variabili (anticipato dal
   passo 3) e permessi DB ridotti a `mp_wallets`.
3. **Database e indicizzatore**: migration (manuale) che elimina `nodes`,
   `blockchains`, `smart_contract`, `contract_type`, valori standard, `ethtxs`
   e la colonna `transactions.id_smart_contract`; fixture dei test aggiornate.

## Criteri di accettazione

- Nessun URL RPC o indirizzo di token preso dal database o dagli utenti.
- Le vecchie pagine (`/nodes`, `/smartcontracts`, `/blockchains`) rispondono 404.
- Test chain, interfaccia, sicurezza e indicizzatore verdi a ogni passo.
