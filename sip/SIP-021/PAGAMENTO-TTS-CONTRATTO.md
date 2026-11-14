# SIP-021 fase 3 - Primo pagamento TTS locale: contratto (APPROVATO)

Bozza 2026-11-14 (CLA master ad interim), decisioni del paragrafo 8 approvate
dall'utente lo stesso giorno. Solo chain locale, nessun denaro reale.

## 1. Evidenze

- Chain locale Besu IBFT, chain id 2118, RPC interno `besu:8545`; indirizzo del
  contratto TTS pubblicato da `chain-deploy` in `/data/tts.json`.
- Token `TTSToken` (Solidity 0.5.17, OpenZeppelin 2.4.0): ERC20 standard,
  2 decimali, 1 TTS = 1 euro (stesso assunto del legacy).
- Wallet `poawallet`: legge QR nel formato legacy `indirizzo&amount=..&message=..`;
  il messaggio resta solo nel DB del wallet, non arriva on-chain.
- Legacy POS (`ReceiveCommand`): la fattura era abbinata al primo trasferimento
  verso l'indirizzo del merchant dopo la creazione, senza controllo
  dell'importo ne del riferimento. Non va riprodotto.
- Napay v2 non ha oggi ne l'indirizzo wallet del merchant ne un client RPC; il
  dataset importato non contiene `np_wallets`.

## 2. Modello

- Nuova tabella richieste di pagamento: merchant, negozio, terminale, apertura,
  operatore, importo in centesimi TTS, indirizzo destinazione congelato alla
  creazione, riferimento casuale a 128 bit, blocco di partenza, scadenza,
  stato, hash e blocco della transazione abbinata, chiave di idempotenza.
- Hash di transazione UNIQUE: una transazione paga al massimo una richiesta.
- Stati: `pending`, `paid`, `expired`, `cancelled`. Nessun ritorno da uno
  stato finale. Anomalie (importo diverso, pagamento tardivo) restano
  registrate per il gestore, senza cambiare stato in automatico.

## 3. Destinazione del merchant

- Indirizzo wallet del merchant impostato dal gestore nel backoffice, validato
  (formato e checksum EIP-55), tracciato nel registro attivita. Tutti i POS del
  merchant usano quell'indirizzo; il POS non lo invia mai.
- La prova di possesso dell'indirizzo non e parte della fase 3 (chain locale):
  resta un blocco esplicito prima di qualunque uso reale.

## 4. API POS (stessi header e fencing delle aperture)

- Creazione: solo con apertura attiva del terminale e sessione operatore
  valida; importo positivo entro un massimo configurato; chiave di
  idempotenza obbligatoria (replay = stessa richiesta, corpo diverso = conflitto).
  Risposta: identificativo, importo, scadenza (15 minuti), contenuto del QR.
- Lettura stato: solo richieste del terminale e dell'apertura correnti.
- Annullamento: solo se `pending` e da parte della stessa apertura.
- Apertura revocata o scaduta: nessuna nuova richiesta; le richieste gia
  create possono ancora risultare pagate e restano visibili al gestore.

## 5. QR e abbinamento

- QR nel formato gia letto dal wallet, con importo e messaggio non modificabili;
  il messaggio porta il riferimento della richiesta.
- Il wallet, se il messaggio e un riferimento Napay valido, lo accoda ai dati
  della chiamata `transfer` del token (il contratto 0.5 ignora i byte in piu;
  da verificare con un test reale prima del codice applicativo).
- Abbinamento valido solo se, nella stessa transazione confermata: evento
  Transfer del contratto TTS configurato, destinatario = indirizzo congelato,
  valore = importo esatto, riferimento nei dati = riferimento della richiesta,
  blocco successivo alla creazione e precedente alla scadenza.

## 6. Rilevazione

- Nessun daemon. La lettura stato del POS esegue, sotto lock della richiesta,
  una ricerca limitata dei log Transfer verso l'indirizzo congelato dal blocco
  di partenza, con timeout breve; RPC non disponibile = stato invariato.
- Comando one-shot per scadenze e richieste abbandonate, come i worker BTCPay.
- RPC in sola lettura su rete interna, chain id verificato, nessuna chiave
  privata in Napay.

## 7. Lato POS e ricevuta

- Tastierino importo, QR con importo e scadenza, attesa con polling dello
  stato, esito pagato/scaduto/annullato, ricevuta minima (importo, data,
  negozio, hash transazione abbreviato). Mobile-first, nessun dato sensibile in
  cache PWA.

## 8. Decisioni richieste all'utente

1. Abbinamento con riferimento on-chain nei dati della transazione (richiede una
   piccola modifica all'invio del wallet `poawallet`), in alternativa a una sola
   richiesta aperta per merchant con importo esatto (nessuna modifica wallet, ma
   i POS dello stesso merchant si bloccano a vicenda e i pagamenti doppi o
   tardivi restano ambigui). Proposta: riferimento on-chain.
2. Indirizzo del merchant inserito dal gestore, senza prova di possesso in
   fase 3. Proposta: si, con blocco esplicito prima dell'uso reale.
3. Verifica durante il polling del POS piu comando one-shot, senza daemon.
   Proposta: si.

Esito (2026-11-14): approvate tutte e tre le proposte. Il daemon in ascolto
sulla chain resta un possibile miglioramento futuro, descritto in
[SIP-027](../SIP-027-tts-listener-daemon.md); non fa parte della fase 3.

## 9. Test previsti (chain e DB usa-e-getta)

Trasferimento reale con riferimento accodato accettato dal contratto; pagamento
corretto; importo diverso; riferimento assente o di altra richiesta; stesso hash
per due richieste; pagamento dopo la scadenza; merchant diverso; replay e
conflitto di idempotenza; apertura revocata; RPC non raggiungibile; chain id
errato. POS: e2e reale con wallet di test, nessun mock del backend.

## 10. Fuori perimetro

Pagamenti BTC, rimborsi, trasferimenti tra merchant, wallet per negozio,
cambio valuta, produzione.

## 11. Gate pre-codice: riferimento accodato (2026-11-14)

Prova su chain usa-e-getta (Besu, chain id 2118, `TTSToken` pubblicato da
`chain-deploy`, stack rimosso a fine prova): 6 PASS. Il trasferimento con
riferimento di 16 byte accodato riesce, l'evento Transfer ha destinatario e
importo esatti, il saldo cresce dell'importo esatto, i dati della transazione
minata finiscono con il riferimento; il trasferimento senza riferimento resta
valido. Evoluzione con funzione di spesa dedicata: [SIP-028](../SIP-028-nuovo-token-tts-sconto-temporaneo.md).
