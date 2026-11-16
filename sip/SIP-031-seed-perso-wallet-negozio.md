# SIP-031 - Seed perso del wallet di un negozio (TTS e BTC)

- Stato: IN SVILUPPO (TTS fatto 2026-11-16; BTC in attesa degli incassi BTC dei negozi)
- Area: Merchant / Negozi / POS / Incassi
- Repo: `napay`, `pos`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-16

## Contesto

Il gestore può perdere il seed del wallet che riceve gli incassi di un negozio
(caso reale in sandbox, 2026-11-16). I fondi già ricevuti su quell'indirizzo non
sono più recuperabili e ogni nuovo pagamento verso quell'indirizzo andrebbe perso.

## Requisiti dell'utente

1. Nel wallet TTS del negozio si può **segnalare il seed perso**.
2. Le vecchie transazioni legate a quel wallet vengono **contabilizzate come
   perdute**.
3. La segnalazione **blocca subito i POS** collegati a quel negozio.
4. Lo stesso vale per il **wallet BTC** del negozio.

## Proposta (da approvare)

- Azione "Segnala seed perso" nella pagina del wallet del negozio: POST con CSRF,
  conferma e motivazione obbligatoria; solo il gestore del merchant o l'admin.
- Nella stessa transazione:
  - l'indirizzo passa in uno storico dei wallet del negozio con stato "perso",
    data, autore e motivazione; il negozio resta senza wallet;
  - richieste di pagamento ancora in attesa verso quell'indirizzo annullate
    (il QR mostrato non è più valido);
  - aperture attive dei terminali del negozio chiuse (motivo dedicato): il POS
    torna alla scelta della cassa con il messaggio "wallet da reimpostare";
  - nuove aperture e nuovi incassi del negozio rifiutati finché non viene salvato
    un nuovo indirizzo.
- Contabilità:
  - Incassi: i pagamenti pagati sull'indirizzo perso restano nello storico con
    l'indicazione "fondi persi" e un totale separato;
  - dashboard: il saldo dei wallet esclude gli indirizzi persi.
- BTC: stesso flusso sul wallet BTCPay del negozio (chiave pubblica/derivation
  scheme): incassi BTC bloccati fino alla nuova chiave; fatture già saldate
  segnate come fondi persi.
- Registro attività per ogni segnalazione, senza dati personali.

## Decisioni utente (2026-11-16)

1. Il blocco dei POS riguarda **solo gli incassi** (TTS e BTC): la cassa si può
   ancora aprire, ma non può incassare finché il negozio non ha un nuovo wallet.
2. Un indirizzo segnalato perso **si può salvare di nuovo** (seed ritrovato).
3. La segnalazione **non si annulla**; prima di inviarla serve una doppia
   conferma: scrivere `CONFERMA` (italiano) o `CONFIRM` (inglese), secondo la
   lingua dell'utente, in un campo di testo.
4. Indirizzo perso salvato di nuovo (seed ritrovato): i suoi incassi passati
   **tornano nei totali normali e nel saldo**, con la voce "indirizzo
   ritrovato" nel registro attività.

## Avanzamento

- 2026-11-16 parte TTS fatta (napay `2fa66e43`, pos `88c597f`): segnalazione con
  motivazione e parola di conferma, indirizzo tolto dai negozi del merchant,
  richieste in attesa annullate, fondi persi separati in Incassi/CSV/dashboard,
  ritrovamento con il nuovo salvataggio dello stesso indirizzo. Test incassi
  TTS 119.
- BTC: nella v2 i negozi non incassano ancora in BTC (BTCPay serve solo le
  quote associative). Il blocco BTC si aggancia quando arrivano gli incassi
  BTC dei negozi (SIP-022): stesso flusso sul wallet BTCPay del negozio.
