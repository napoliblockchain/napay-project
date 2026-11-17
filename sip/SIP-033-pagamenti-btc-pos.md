# SIP-033 - Pagamenti BTC dal POS

- Stato: APPROVATO (2026-11-17), in corso
- Area: POS / Napay / BTCPay / Pagamenti
- Repo: `pos`, `napay`, `napay-project` (collaudo)
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-17
- Dipendenze: SIP-021 (POS, aperture), SIP-022 (store, app POS, xpub, webhook per store)

## Contesto

Il POS v2 incassa solo in TTS: i pagamenti BTC erano esclusi dalla prima
versione (SIP-021, "richiedono documentazione prima del codice"). Con SIP-022
ogni negozio ha il suo store BTCPay, ogni terminale la sua app POS, il wallet
BTC è la xpub del merchant e gli eventi delle fatture arrivano a Napay con
webhook firmati per store.

Vincolo: il web di Napay non usa mai la chiave del merchant (solo il worker,
modello P3); il worker gira a intervalli, troppo lento per un cliente in cassa.

## Verifica su BTCPay 2.4.7 (regtest usa-e-getta, 2026-11-17)

- L'app POS crea fatture con un POST HTTP **senza chiave API né token
  anti-CSRF**: risposta 302 verso la pagina della fattura (`/i/{id}`).
- Importo e valuta (EUR) sono quelli passati; il campo `orderId` passato dal
  chiamante viene salvato nella fattura (collegamento al pagamento Napay).
- L'app POS deve avere l'importo libero attivo; quella creata oggi dal
  provisioning ha solo il nome (impostazioni da aggiungere, passo 1).
- Senza Internet (regtest) servono cambi fissi nello store; in produzione i
  cambi arrivano dalle borse configurate su BTCPay.

- La pagina di stato pubblica della fattura (per metodo di pagamento BTC
  on-chain) restituisce in JSON, senza chiave: indirizzo, importo dovuto in BTC,
  URI di pagamento BIP21, secondi alla scadenza, stato e conferme. Basta per
  disegnare il QR nel POS (D2 verificata).

L'app POS è pubblica per natura (chiunque con il suo indirizzo può creare
fatture): Napay considera solo le fatture che ha creato e registrato lui.

## Proposta

1. **App POS configurata dal provisioning**: importo libero, vista tastierino,
   valuta del negozio, aggiornata con le impostazioni dello store.
2. **Tasto "Paga in BTC"** nel POS, solo se il negozio ha il wallet BTC e il
   terminale ha l'app POS collegata. Il cassiere inserisce l'importo come per
   il TTS.
3. **Fattura immediata**: il backend Napay (richiesta del POS autenticata come
   oggi, apertura del terminale valida) crea la fattura tramite l'app POS del
   terminale, attraverso il proxy di uscita, con `orderId` = identificativo del
   pagamento Napay; salva pagamento BTC, ID fattura, importo, scadenza.
4. **Pagamento del cliente**: QR della fattura sullo schermo del POS (vedi
   decisione D2), conto alla rovescia della scadenza (15 minuti).
5. **Esito dai webhook firmati dello store** (SIP-022 passo 4): l'evento con
   l'ID fattura registrato aggiorna il pagamento; il POS interroga Napay come
   per il TTS. Fatture non create da Napay: ignorate.
6. **Storico e totali**: pagamenti BTC nello storico del POS e del backoffice e
   nei totali della dashboard, distinti dal TTS.
7. **Collaudo reale**: regtest con pagamento vero (bitcoind del regtest invia
   a un indirizzo della fattura), dall'apertura del terminale all'esito.

## Decisioni (2026-11-17)

- **D1 Stato "pagato"**: "ricevuto, in conferma" all'arrivo della transazione
  (`InvoiceProcessing`, 0 conferme), "confermato" a `InvoiceSettled`. Il
  cassiere può chiudere la vendita al primo stato; l'esito finale resta nello
  storico.
- **D2 QR nel POS**: generato dal POS con l'URI BIP21 letto dal backend Napay
  dalla pagina di stato pubblica della fattura. Ripiego, se in collaudo non
  funziona: apertura della pagina di pagamento di BTCPay.
- **D3 Lightning**: escluso, solo on-chain sulla xpub del merchant.

## Passi

1. FATTO (napay `a823a4b0`): app POS configurata dal provisioning (importo
   libero, vista tastierino, valuta del negozio). Verificato su BTCPay: il PUT
   dell'app sostituisce tutta la configurazione e la valuta dell'app non segue
   lo store, quindi `store_update` rimanda la configurazione completa a ogni app
   collegata del negozio. Le app create prima di questo passo si allineano al
   primo salvataggio del negozio. Collaudo e2e: fattura anonima dall'app,
   stato pubblico con indirizzo della xpub del merchant.
2. Schema: tabella dei pagamenti BTC del POS (permessi per ruolo DB).
3. Backend Napay: creazione fattura via proxy, lettura dello stato pubblico,
   aggiornamento dai webhook firmati dello store.
4. POS: tasto "Paga in BTC", QR, scadenza, stati "ricevuto"/"confermato".
5. Storico e totali (POS e backoffice).
6. Collaudo e2e sul regtest con pagamento reale.

## Fuori perimetro

- Negozi importati da v1 (store BTCPay già esistenti): dipendono dalla
  mappatura delle app POS di SIP-030; fino ad allora niente tasto BTC.

## Sicurezza

- Nessuna chiave BTCPay nel POS né nel web; uscita solo dal proxy.
- Importo e terminale decisi dal backend (apertura valida), mai dal browser
  del POS; `orderId` solo come riferimento, il collegamento è l'ID fattura
  registrato da Napay alla creazione.
- Esito solo da webhook con firma valida per quello store, consegne
  deduplicate; nessun evento cambia un pagamento di un altro negozio.
- Limiti di frequenza per terminale sulla creazione di fatture.

## Criteri di accettazione

- Tasto BTC visibile solo con wallet BTC e app POS collegata.
- Fattura creata in pochi secondi senza chiavi; importo e valuta corretti.
- Pagamento sul regtest: il POS passa a "ricevuto" e poi "confermato";
  fattura scaduta o non valida mostrata come tale.
- Storico e totali aggiornati; nessun segreto nei log; test e collaudo verdi.
