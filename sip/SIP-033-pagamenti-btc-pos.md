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
2. FATTO (napay `00fe8a00`): schema `pos_btc_payments` e permessi per ruolo
   DB (contratto sotto). Test: schema 55, ruoli 73.
3. FATTO (napay `3b791827`): backend Napay. Contratto sotto. Test: servizio
   e API 41, ruoli 75, e2e regtest 23 (gateway reale via proxy e TLS).
4. FATTO (pos `e46c208`, napay `18b07b53`): tasto "Incassa in BTC" sul
   tastierino solo se Napay lo dichiara disponibile (valuta del negozio
   accanto all'importo); pagina BTC con QR BIP21, importo BTC, indirizzo, conto
   alla rovescia, link alla pagina BTCPay come ripiego; "ricevuto" permette di
   chiudere la vendita, "confermato" arriva col polling. Risposte di Napay
   validate campo per campo. Test: client/controller POS 114, e2e POS-Napay
   pagamenti verde. Ricevuta PDF dei pagamenti BTC rimandata al passo 5.
5. FATTO (napay `9739dccf`, `cc443fb4`, `22e25053`; pos `a9f18c5`, `8f06919`,
   `edd21f1`): cambio e dettaglio BTC, storico e totali, backoffice, ricevuta.
   Contratto sotto. Test: pagamenti BTC 53, TTS 62+30+20, e2e regtest 26,
   schema 55, client/controller POS 142, e2e POS-Napay pagamenti verde.
6. FATTO (2026-11-18, sandbox, cassa latitude-pos-03-btc): 1,50 EUR = 2623 sat
   al cambio Kraken 57.199,00 + 10000 sat di fee di rete (stima regtest);
   pagato il QR con `local.sh pay` (orchestratore `5218799`): "ricevuto" in
   3 s, `mine 1` -> "confermato" in 3 s; fattura Settled su BTCPay con
   l'orderId di Napay; storico, totali di oggi (2 incassi, 2,50 EUR,
   0.00024363 BTC) e ricevuta corretti; risposte reali accettate dal client
   del POS. Esito: gli stati arrivano dal polling (pagina POS) e dal sweep;
   i webhook dello store non arrivavano nella sandbox (`napay.local` non
   risolveva nel container BTCPay, gateway chiuso alla rete edge, protezione
   SSRF di BTCPay sulle reti private). Abilitati con eccezioni strette
   (orchestratore, sotto): con il solo webhook "ricevuto" in 1 s e
   "confermato" in 1 s dal blocco.
   Webhook = solo avviso (napay): dal webhook si prende l'ID della fattura,
   stato, BTC ricevuti e conferme si rileggono dallo stato pubblico di BTCPay.
   Sandbox: alias `napay.local` del gateway sulla rete edge; gateway aperto
   alla edge solo per `POST /api/btcpay/v1/store-webhook`; BTCPay con
   `BTCPAY_SSRFEXCEPTIONS=napay.local:443`, `NO_PROXY` e CA del gateway in
   `SSL_CERT_DIR` (in aggiunta alle CA di sistema). Produzione: se BTCPay
   raggiunge Napay su un indirizzo privato serve la stessa eccezione SSRF.

## Contratto passo 2 - schema e ruoli (2026-11-18)

- Tabella additiva e vuota `pos_btc_payments`, distinta dai pagamenti TTS e
  dalle quote associative. Nessuna chiamata BTCPay o import legacy.
- UUID pubblico casuale; merchant/negozio/terminale/apertura/sessione/operatore
  congelati alla creazione. FK composite negozio-merchant e terminale-negozio-
  merchant; apertura/sessione/utente con FK RESTRICT, coerenza reciproca da
  ricontrollare sotto lock dal servizio del passo3 (come TTS).
- Snapshot istanza BTCPay (digest origine), ID store/app remoti pubblici,
  importo intero `amount_cents` (1..100000, stesso limite POS TTS), valuta
  fiat uppercase3 del negozio. Nessun float, token, password, xpub o payload
  webhook nella tabella. Validazione valuta/importo supportati nel passo3.
- Unicita UUID, chiave idempotenza hash per sessione, fattura per istanza.
  Hash richiesta impedisce replay con parametri diversi; orderId = UUID
  pubblico. L'ID fattura nullable viene salvato solo dopo risposta verificata.
- Stati: creating -> pending -> processing -> settled; expired/invalid e
  failed (creazione rifiutata). Esito POST ignoto = reconcile_required:
  checkpoint creation_started_at persistito PRIMA della rete, stesso replay
  non invia un altro POST. Recupero incerto escluso dal solo passo schema.
- Campi opzionali indirizzo BTC e satoshi dovuti (coppia coerente), conferme,
  timestamp ricezione/conferma/chiusura, errore codificato e versione CAS.
  Ricezione e conferma distinguibili; settled puo arrivare senza processing.
  Vincoli SQL su formati, importi, stato/fattura/timestamp; nessun cascade.
- Web SELECT/INSERT/UPDATE, mai DELETE; worker provisioning nessun accesso;
  migrator DDL/verifica completa. Nessun grant a chiavi BTCPay per POS/web.
- Migrazione ripetibile solo su definizione identica (modello migrazione
  TTS esistente), schema differente rifiutato, rollback distruttivo vietato.
  Bootstrap importato non rilanciato; nessuna migration sandbox in questo step.

Test: replay e schema alterato, CHECK/UNIQUE/FK e scope inter-merchant,
stati processing/settled, importi/timestamp invalidi, permessi effettivi con
connessioni web/worker/migrator, regressioni ruoli e provisioning passo1.

## Contratto passo 3 - backend (2026-11-18)

- Configurazione: il web e il cron ricevono l'origine BTCPay del provisioning
  e la CA locale; l'origine deve dare lo stesso digest dell'istanza, altrimenti
  pagamenti BTC spenti. Uscita dal proxy se configurato, come per le quote.
- Disponibilità: negozio con wallet BTC (xpub, non v1), store e app POS del
  terminale collegati sulla stessa istanza, valuta EUR o USD. L'API "metodi"
  dice al POS se mostrare i tasti TTS e BTC.
- Creazione: stesse regole e lock dei pagamenti TTS; riga salvata prima della
  rete, poi un solo POST anonimo all'app POS con riferimento = ID pubblico
  Napay. Fattura accettata solo se lo stato pubblico conferma ID, riferimento,
  store, valuta e importo; altrimenti `invalid` e mai mostrata.
- Esito ignoto del POST: `reconcile_required`, la stessa richiesta non invia un
  secondo POST; lo sweep la chiude come fallita dopo la scadenza (nessun QR è
  stato mostrato, la fattura scade su BTCPay).
- Esiti: webhook firmati dello store (Processing = ricevuto, Settled =
  confermato, Expired, Invalid) e stato pubblico letto da Napay sul server
  BTCPay via TLS (la sandbox non riceve webhook). Mai valori dal browser del
  POS. Solo transizioni in avanti con controllo di versione.
- Risposta al POS: importo e valuta, indirizzo, importo BTC, QR BIP21 costruito
  da Napay, link alla pagina di pagamento BTCPay (ripiego D2), conferme,
  errore codificato. Mai ID remoti di store o app, sessione o ID fattura.
- Sweep ogni 5 minuti dal cron; il web può leggere l'ID dell'app POS del
  terminale (non segreto), mai i marker.

## Contratto passo 5 - storico, totali, ricevuta (2026-11-18)

- Dallo stato pubblico della fattura (solo interi): `order_satoshis` (ordine
  senza fee di rete), `paid_satoshis` (ricevuti, sempre aggiornati),
  `rate_cents` (valuta per 1 BTC). Il cambio arriva come testo formattato
  nella lingua dello store: accettato solo se coerente con importo e satoshi
  dell'ordine (scarto massimo 0,2% oltre il satoshi), altrimenti mai salvato
  né mostrato. Fee di rete = totale richiesto meno ordine ("Network fee:
  Always" degli standard dello store).
- Colonne opzionali additive in `pos_btc_payments` (m261118_150000) con un
  vincolo; la verifica della migration del passo 2 riconosce solo questa
  estensione esatta.
- API POS: il pagamento BTC espone `rate`, `order_btc`, `network_fee_btc`,
  `paid_btc`; lo storico `GET openings/{id}/payments` unisce TTS e BTC
  (ultimi 50 in 30 giorni, campo `method`, mai indirizzo, QR o fattura) e
  aggiunge i totali di oggi del terminale dalla mezzanotte (Roma): TTS pagati,
  BTC ricevuti o confermati per valuta con i BTC incassati.
- POS: dettaglio BTC (cambio, ordine + fee, pagati), richiesta scaduta con
  "Torna alla cassa", storico con simboli e totali, ricevuta A7 per pagamenti
  ricevuti (D1) o confermati; risposte di Napay fino a 32 KB.
- Backoffice "Incassi POS": TTS e BTC in un elenco (filtro Metodo), stati BTC
  raggruppati nei quattro filtri esistenti, totali BTC per valuta, dettaglio
  ed export CSV con cambio e BTC pagati. Mai ID remoti BTCPay o fattura.

## Fuori perimetro

- Negozi importati da v1 (store BTCPay già esistenti): dipendono dalla
  mappatura delle app POS di SIP-030; fino ad allora niente tasto BTC.

## Sicurezza

- Nessuna chiave BTCPay nel POS né nel web; uscita solo dal proxy.
- Importo e terminale decisi dal backend (apertura valida), mai dal browser
  del POS; `orderId` solo come riferimento, il collegamento è l'ID fattura
  registrato da Napay alla creazione.
- Esito da webhook con firma valida per quello store (consegne deduplicate,
  nessun evento cambia un pagamento di un altro negozio) o dallo stato
  pubblico letto da Napay sul server BTCPay configurato.
- Limiti di frequenza per terminale sulla creazione di fatture.

## Criteri di accettazione

- Tasto BTC visibile solo con wallet BTC e app POS collegata.
- Fattura creata in pochi secondi senza chiavi; importo e valuta corretti.
- Pagamento sul regtest: il POS passa a "ricevuto" e poi "confermato";
  fattura scaduta o non valida mostrata come tale.
- Storico e totali aggiornati; nessun segreto nei log; test e collaudo verdi.
