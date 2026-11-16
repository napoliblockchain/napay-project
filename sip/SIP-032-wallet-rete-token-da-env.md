# SIP-032 - Wallet: una rete e un token dalle variabili d'ambiente

- Stato: FATTO (2026-11-16)
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
3. **Database** (fatto, poawallet `d16e9c8`): migration
   `m261116_100000_drop_per_user_network_tables` che toglie prima il vincolo
   `transactions` -> `smart_contract` (con CASCADE eliminerebbe le transazioni),
   poi la colonna `transactions.id_smart_contract` e le tabelle `nodes`,
   `smart_contract`, `blockchains`, `contract_type`, valori standard, `ethtxs`,
   `ethtxs_status`. Fixture dei test aggiornate; il test UI verifica che tabelle
   e colonna non esistano più.

## Migration in sandbox e in produzione

- Sandbox condivisa: a mano (`docker exec -it wallet-web php yii migrate`),
  dopo il rebuild del wallet (il codice vecchio scrive ancora la colonna).
- VPS: automatiche al deploy, come Napay (job one-shot prima del web). Da
  definire nel deploy del wallet v2, che oggi non esiste ancora.

## Criteri di accettazione

- Nessun URL RPC o indirizzo di token preso dal database o dagli utenti.
- Le vecchie pagine (`/nodes`, `/smartcontracts`, `/blockchains`) rispondono 404.
- Test chain, interfaccia, sicurezza e indicizzatore verdi a ogni passo.
