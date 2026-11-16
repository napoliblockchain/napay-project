# SIP-032 - Wallet: una rete e un token dalle variabili d'ambiente

- Stato: IN SVILUPPO (passo 1 fatto 2026-11-16)
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
2. **Rimozione di pagine e righe per utente**: controller, viste e modelli di
   nodi, reti, token, tipi di contratto e valori standard; wizard e ripristino
   non creano più righe; menu con solo "Network info".
3. **Database e indicizzatore**: migration (manuale) che elimina `nodes`,
   `blockchains`, `smart_contract`, `contract_type`, valori standard, `ethtxs`
   e la colonna `transactions.id_smart_contract`; l'indicizzatore Go usa il
   token configurato; fixture dei test aggiornate.

## Criteri di accettazione

- Nessun URL RPC o indirizzo di token preso dal database o dagli utenti.
- Le vecchie pagine (`/nodes`, `/smartcontracts`, `/blockchains`) rispondono 404.
- Test chain, interfaccia, sicurezza e indicizzatore verdi a ogni passo.
