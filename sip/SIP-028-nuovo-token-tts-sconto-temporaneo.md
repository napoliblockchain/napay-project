# SIP-028 - Nuovo token TTS: Token Temporaneo di Sconto a circuito chiuso

- Stato: OPEN
- Area: Blockchain / Fidelity / Economia circolare
- Repo: `ttstoken`, `napay`, `poawallet`, `pos`, `napay-project`
- Branch target: `feature/v2-*` (nuovo contratto in `ttstoken`)
- Segnalato: 2026-11-14

## Contesto

Scopo del progetto (linee guida iniziali): realizzare un sistema di fidelity e
tokenizzazione per lo sviluppo sperimentale di un'economia circolare virtuosa,
che educhi e incentivi i cittadini a conferire correttamente i materiali
riciclabili in cambio di una premialita spendibile come sconto. I cittadini
guadagnano i token partecipando ad attivita utili alla comunita e li spendono
come sconto presso le attivita commerciali locali aderenti. Il sistema
promuove la partecipazione civica ed esplora l'uso della blockchain
nell'amministrazione locale e nel commercio.

Il contratto attuale (`TTSToken`, Solidity 0.5.17 + OpenZeppelin 2.4.0, gia in
produzione, vedi SIP-017) e un ERC20 generico. Non ci sono bug nel codice, che e
tutto OpenZeppelin, ma il disegno non corrisponde allo scopo:

- **il token non e temporaneo:** non scade mai, quindi non spinge a spenderlo
  e chi lo riceve puo accumularlo;
- **circola liberamente:** ogni indirizzo puo trasferirlo a chiunque, quindi
  nascono scambi tra privati e un possibile mercato secondario, contrari a un
  buono sconto;
- **conio senza limite e senza tracce:** un solo ruolo puo creare token
  ovunque e in qualunque quantita, la chiave e quella del validatore della
  chain, e non resta nessuna traccia di quale attivita ha generato il premio;
- **ciclo di vita incompleto:** manca un blocco d'emergenza e manca la
  distruzione dei token spesi, quindi non si puo rendicontare chiaramente il
  ciclo emissione, spesa, chiusura;
- **dettagli datati:** fornitura iniziale di 10,00 TTS senza scopo, versione
  del compilatore non fissata, toolchain datata.

## Proposta

Nuovo contratto TTS, non aggiornabile, scritto da zero su una base OpenZeppelin
recente e con un compilatore fissato. Le regole sono pensate per un buono
sconto, non per una moneta.

### 1. Valore e unita
- 2 decimali; 1 TTS = 1 euro di sconto nominale. Non e denaro: non si compra,
  non si rimborsa in euro e non si converte.

### 2. Temporaneita (scadenza per lotti)
- Ogni emissione forma un lotto con la scadenza del periodo in cui e stato
  emesso: fine del mese di emissione piu N mesi, con N fissato alla
  pubblicazione (proposta 12).
- Il saldo spendibile somma solo i lotti non scaduti. La spesa consuma prima i
  lotti piu vecchi.
- I lotti sono raggruppati per mese, quindi per ogni cittadino ce ne sono al
  massimo N+1: costo prevedibile e nessuna crescita senza limite.
- I token scaduti non si spendono piu. Possono essere azzerati, con un evento
  pubblico, da chiunque e senza alcun privilegio, cosi i totali restano
  corretti.

### 3. Circuito chiuso
- Tre categorie di indirizzi, ciascuna registrata da un ruolo dedicato:
  - **emettitori:** ecoisole, centri di raccolta, enti promotori;
  - **esercenti aderenti;**
  - **cittadini:** qualunque altro indirizzo.
- Movimenti ammessi:
  - emissione da emettitore a cittadino;
  - spesa da cittadino a esercente aderente;
  - chiusura da parte dell'esercente, cioe distruzione dei token ricevuti con
    un riferimento di rendicontazione.
- Vietati gli scambi tra cittadini, tra esercenti e verso indirizzi non
  registrati come esercenti: niente mercato secondario.
- Un esercente sospeso o rimosso non puo piu ricevere token. Puo comunque
  chiudere quelli gia ricevuti.

### 4. Emissione responsabile
- Solo gli emettitori autorizzati possono emettere.
- Ogni emissione porta:
  - un codice di attivita (per esempio il tipo di materiale conferito);
  - un identificativo univoco del conferimento, che impedisce di emettere due
    volte per lo stesso conferimento.
- Limiti per periodo, per emettitore e per cittadino, con tetto massimo
  globale configurato alla pubblicazione.
- Sulla chain non va nessun dato personale. Il legame tra indirizzo e persona
  e i dettagli del conferimento (pesi, foto, luogo) restano fuori dalla chain,
  nei sistemi Napay.

### 5. Pagamento con riferimento
- Funzione di spesa dedicata che riceve esercente, importo e riferimento della
  richiesta di pagamento, ed emette un evento con il riferimento.
- Sostituisce il riferimento accodato ai dati della transazione, usato solo per
  il collaudo della fase 3 di SIP-021. L'abbinamento in Napay legge l'evento e
  le regole restano le stesse.

### 6. Governance e sicurezza
- Ruoli separati:
  - amministrazione, con firma multipla e attesa prima dell'esecuzione;
  - registro esercenti;
  - registro emettitori;
  - blocco d'emergenza.
- Nessun ruolo alla chiave del validatore.
- Il blocco d'emergenza ferma emissione e spesa, non la lettura dei saldi.
- Nessuna funzione per spostare saldi altrui, confiscare o coniare fuori dal
  flusso di emissione.
- Rinuncia e passaggio dei ruoli in due passi.

### 7. Trasparenza ed educazione
- Eventi pubblici per emissione, spesa, chiusura e scadenza, divisi per codice
  di attivita. Permettono un cruscotto pubblico: premi emessi, sconti usati,
  quota scaduta per periodo.
- Gli indicatori ambientali (chili conferiti, tipo di materiale) restano fuori
  dalla chain, collegati all'identificativo del conferimento.

### 8. Costi per il cittadino
- Chain POA con gas a costo zero (come oggi): il cittadino non ha bisogno di
  criptovaluta.
- Da valutare: firme delegate, cosi i wallet leggeri non devono gestire il
  nonce.

## Migrazione dal TTS attuale
- Fotografia dei saldi del vecchio contratto a un blocco annunciato.
- Riemissione nel nuovo contratto come lotto unico con scadenza propria.
- Il vecchio contratto non si puo bloccare. Il minter rinuncia al ruolo, poi
  wallet, POS e Napay smettono di accettarlo.
- Nessuna modifica al vecchio contratto, che e immutabile.

## Criteri di accettazione
- Un token scaduto non si spende in nessun percorso, compresi gli ordini di
  spesa al confine della scadenza.
- Scambi tra cittadini e verso indirizzi non registrati sempre rifiutati.
- Nessuna emissione oltre i limiti o con un identificativo di conferimento gia
  usato.
- Spesa con riferimento abbinata da Napay senza ambiguita. Collaudo end-to-end
  con wallet, POS e Napay su chain locale.
- Test unitari e di proprieta (invarianti di fornitura e scadenza), analisi
  statica, revisione indipendente.
- Audit esterno prima della produzione.
- Nessun dato personale sulla chain.

## Impatto
- `ttstoken`: nuovo contratto, test e script di pubblicazione; la toolchain di
  `docker/chain/tools` passa alla nuova versione per la chain locale.
- `poawallet`:
  - saldo spendibile e scadenze dei lotti;
  - invio solo a esercenti aderenti;
  - spesa con riferimento.
- `napay`:
  - registri di esercenti ed emettitori;
  - emissione legata ai conferimenti;
  - abbinamento dei pagamenti sugli eventi;
  - cruscotto.
- `pos`: nessun cambio di flusso; QR e abbinamento restano quelli della fase 3.

## Note implementative
- Da fare dopo il collaudo della fase 3 di SIP-021. Non blocca il 23/11 e non
  entra nel suo perimetro.
- Prima del codice serve un parere legale. Da chiarire:
  - inquadramento dei buoni sconto a circuito chiuso, non convertibili, nella
    rete limitata del Comune e degli esercenti;
  - fiscalita dello sconto;
  - trattamento dati (GDPR) del legame tra indirizzo e persona.
- Decisioni aperte per l'utente:
  1. durata dei lotti (proposta 12 mesi dalla fine del mese di emissione);
  2. chi finanzia lo sconto e se la chiusura dell'esercente ha una
     contropartita, fuori dalla chain;
  3. attivita premiate oltre ai conferimenti di materiale riciclabile;
  4. limiti di emissione per cittadino e per periodo;
  5. composizione della firma multipla di amministrazione (Comune,
     associazione, gestore tecnico).
- Rischi:
  - logica di scadenza piu complessa di un ERC20, da coprire con test di
    proprieta e audit;
  - compatibilita con i wallet generici, voluta solo in parte perche il
    circuito chiuso limita i trasferimenti.
