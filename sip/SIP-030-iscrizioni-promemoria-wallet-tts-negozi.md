# SIP-030 - Approvazione iscrizioni, promemoria quote, wallet TTS per negozio

- Stato: APPROVATO (decisioni utente 2026-11-16), in sviluppo per punti
- Area: Associazione / Merchant / POS TTS
- Repo: `napay` (backoffice), `napay-project` (orchestratore, worker)
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-16

## Contesto

Analisi del Napay v1 in produzione (`napay-1`, Yii 1.1, ultimo commit 2023-03-28)
su tre funzioni che la v2 non ha ancora o ha in forma diversa: la lista delle
richieste di iscrizione approvate dall'admin, i promemoria di scadenza della
quota e il wallet TTS che riceve gli incassi del POS.

## 1. Richieste di iscrizione

### Come funziona nella v1

- La registrazione pubblica crea l'utente non attivo (`status_activation_code = 0`).
  La mail all'iscritto non contiene un link di attivazione: annuncia che
  l'iscrizione sarà approvata e che poi arriveranno le istruzioni per la quota.
  Il login di un utente non attivo è rifiutato.
- Fa eccezione il primo utente dell'installazione, che diventa amministratore e
  riceve il link di attivazione.
- Una mail "nuova iscrizione" parte subito a tutti gli amministratori, per ogni
  registrazione.
- "Richieste Iscrizione" (menu Amministrazione e riquadro in dashboard con
  "Gestisci") elenca tutti gli utenti non attivi. Si selezionano più righe:
  - **Accetta:** l'utente diventa attivo e riceve la mail di conferma. Per una
    persona giuridica, nella stessa operazione, crea il merchant, l'utente
    BTCPay e le notifiche di aiuto. Server blockchain, asset e gateway sono
    scelti dall'admin in un modale.
  - **Rifiuta:** invia una mail con la motivazione scritta dall'admin e
    incrementa "Mail inviate". L'utente **resta non attivo e resta nella lista**.

### Problemi rilevati

- La lista di produzione (schermata del 2026-11-16) contiene account con nomi
  casuali e email di provider pubblici: registrazioni automatiche (bot). Non
  avendo un passo di verifica dell'email, la v1 li mette tutti in lista; il
  rifiuto non li toglie, quindi la lista cresce senza fine.
- Le stesse registrazioni generano una mail agli admin ciascuna.
- Approvazione iscrizione e creazione del merchant sono un'unica azione.

### Stato nella v2

- Registrazione con link di attivazione via email: l'utente si attiva da solo,
  **senza approvazione admin**. La mail agli admin parte alla registrazione,
  prima della verifica dell'email.
- `LegacyImporter` importa anche gli utenti v1 non attivi, come non attivi.
  Il dataset della sandbox (copia di test del 22/10) non ne contiene: in
  produzione la lista v1 ne ha almeno 7 (schermata).
- SIP-022/SIP-023: la PG attiva da sola il proprio merchant, senza approvazione
  admin. Questa regola resta: l'approvazione proposta qui riguarda solo
  l'**iscrizione all'associazione**, non il merchant.

### Proposta

1. Registrazione in due passi: verifica dell'email (link già esistente), poi
   **in attesa di approvazione**. Stato di approvazione nel profilo del socio,
   distinto da `is_active`: in attesa, approvato, rifiutato.
2. La mail agli admin parte solo dopo la verifica dell'email: i bot che non
   confermano non arrivano né agli admin né alla lista.
3. Account mai verificati eliminati in automatico dopo 7 giorni (comando
   periodico del worker).
4. Lista "Richieste di iscrizione" in Amministrazione, solo email verificate:
   nome, email, PF/PG, data di registrazione, consensi dati. Azioni per riga e
   multiple:
   - **Approva:** mail di benvenuto con le istruzioni per pagare la quota;
   - **Rifiuta:** motivazione obbligatoria inviata per mail; la richiesta esce
     dalla lista.
   Entrambe le azioni richiedono POST con CSRF e lasciano una voce nel log.
5. Riquadro in dashboard admin con il numero di richieste in attesa e il link
   alla lista, come nella v1.
6. Dopo l'approvazione la PG attiva il merchant da sé (SIP-023). Niente
   server, asset o gateway da scegliere nel modale di approvazione.
7. Gli operatori POS invitati dai merchant non passano dalla lista: non sono
   soci (SIP-023).

## 2. Promemoria di scadenza della quota

### Come funziona nella v1

- La quota vale per anno solare (scadenza 31/12 dell'ultimo anno pagato).
- "Promemoria" elenca i soci attivi la cui quota scade entro 45 giorni o è
  scaduta da meno di 365 giorni. Esclusi i soci che non hanno mai pagato.
- L'invio è **solo manuale**: l'admin seleziona i soci e invia la mail
  "Avviso adesione scaduta" con il pulsante Rinnova. Un contatore "Solleciti"
  per socio viene incrementato.
- Ai merchant compare in dashboard un avviso di scadenza.

### Problemi rilevati

- Il contatore dei solleciti non si azzera mai: dopo il rinnovo conta anche
  quelli degli anni precedenti.
- Testi incoerenti: la mail chiede il pagamento "entro il 31 gennaio",
  l'avviso in dashboard "entro il 28 febbraio".
- Nessun limite: lo stesso socio può ricevere più solleciti nello stesso giorno.

### Stato nella v2

- Stati del socio già calcolati come nella v1 (`Members`: in regola, in
  scadenza entro 45 giorni, scaduto, decaduto oltre 365 giorni, mai pagato,
  esente). Mancano la lista promemoria e l'invio.
- Nessun processo periodico nel backoffice: oggi i comandi (`tts-payments`
  sweep, provisioning BTCPay) si eseguono una volta (`--once`).

### Proposta

1. Registro degli invii per socio e **per scadenza** (data di scadenza della
   quota, tipo automatico/manuale, data, autore). Il contatore è per periodo,
   quindi riparte da zero dopo il rinnovo.
2. **Primo promemoria automatico**: un comando giornaliero del worker lo invia
   ai soci in scadenza (finestra di 30 giorni prima della scadenza, da
   confermare), una sola volta per scadenza. Idempotente: rieseguirlo non
   invia doppioni.
3. **Successivi manuali** dalla lista "Promemoria": colonne stato, scadenza,
   numero di invii per il periodo, ultimo invio. Pausa minima di 7 giorni tra
   due invii allo stesso socio, anche se selezionato più volte.
4. Esclusi: amministratori esenti, account bloccati, soci decaduti (oltre 365
   giorni), soci che hanno chiesto di non ricevere avvisi (decisione aperta).
5. Un solo testo, con la data di scadenza reale e il link al pagamento della
   quota della v2 (BTCPay/PayPal). Niente date fisse nel testo.
6. Esecuzione del comando giornaliero: servizio worker nel compose, con
   l'utente DB del worker già previsto da `DatabaseRoles`. Niente cron
   sull'host.

## 3. Wallet TTS per negozio

### Come funziona nella v1

- Il wallet BTC è **per negozio**: una chiave pubblica master (MPK) per
  ogni negozio e asset, inviata allo store BTCPay di quel negozio.
- Il wallet TTS è invece per utente (tabella `wallets`), creato nell'app
  wallet esterna e segnalato in dashboard.

### Stato nella v2

- `merchant_tts_wallets`: un indirizzo per merchant, gestito dalla pagina
  "Wallet TTS" nel menu profilo. Ogni incasso TTS del POS va all'indirizzo del
  merchant, qualunque sia il negozio del terminale; `pos_tts_payments` registra
  già il negozio.
- Il tab "Wallet" del negozio (BTC) mostra la derivazione, ma il pulsante
  Modifica porta a `update-wallet`, azione che non esiste nel controller
  (collegamento morto).

### Proposta

1. Indirizzo TTS **per negozio**, come il wallet BTC: nuova tabella con un
   indirizzo per negozio (stesse regole: EIP-55, niente indirizzo zero,
   autore e data, log delle modifiche). Lo stesso indirizzo può servire più
   negozi.
2. Nella pagina del negozio, tab "Wallet BTC" e "Wallet TTS". Per il TTS:
   copia, modifica, elimina e copia con testo Napay, come la pagina attuale.
   Tolta la voce "Wallet TTS" dal menu profilo.
3. Incasso POS: indirizzo del negozio del terminale. Negozio senza wallet TTS:
   incasso TTS non disponibile, come oggi per il merchant senza wallet.
4. Migrazione: l'indirizzo attuale del merchant viene copiato su tutti i suoi
   negozi; poi la tabella per merchant viene rimossa.
5. Dashboard: saldo per negozio e totale degli indirizzi distinti. Incassi già
   filtrabili per negozio.
6. Il pulsante Modifica del wallet BTC va collegato o tolto (vedi punto 4).

## 4. Impostazioni del negozio da nascondere (da approfondire)

Il negozio v2 mostra le impostazioni dello store BTCPay su sei tab. Proposta
iniziale, da discutere prima del codice:

| Tab | Campi | Proposta |
| --- | --- | --- |
| Generale | nome, descrizione | visibili |
| Generale | speed policy, fee di rete, scadenza fattura, metodo e valuta predefiniti | nascosti, valori fissi di piattaforma (EUR) |
| Wallet BTC | derivazione, etichetta, percorso | visibile in lettura; modifica da definire |
| Wallet TTS | indirizzo | visibile, modificabile (punto 3) |
| Tassi | fonte del prezzo, spread | nascosti, valori fissi |
| Checkout | email rimborso, ricevuta, pagamenti e QR in ricevuta | nascosti, valori fissi |
| Criteri | soglie BTC e Lightning | nascosti, valori fissi |
| Webhook | id, URL | gestiti dal sistema, mai mostrati |

I valori fissi stanno in un solo punto della configurazione e vengono applicati
dal provisioning (SIP-022) alla creazione dello store.

## Import dalla v1 in produzione

Sulla VPS gira la v1: all'aggiornamento i dati arrivano dal suo MySQL tramite
`LegacyImporter` (TIP-020), non da un dump. Oggi l'importatore legge utenti,
cariche, quote, pagamenti, verbali e impostazioni non segrete. Per questo SIP
servono in più:

| Dato v1 | Dove | Proposta v2 |
| --- | --- | --- |
| Richieste in sospeso | `np_users.status_activation_code = 0` | importate come "in attesa di approvazione", ma con verifica email da fare: chi non conferma entro 7 giorni viene eliminato (filtra i bot) |
| Mail di rifiuto inviate | `numero_mail_approvazione` nelle impostazioni utente | non importato (nessun uso nella v2) |
| Solleciti quota | `SollecitiPagamenti` nelle impostazioni utente | non importato: contatore senza periodo, non attribuibile a una scadenza |
| Wallet TTS del merchant | tabella `wallets` (per utente) | copiato su tutti i negozi del merchant importato |
| Wallet BTC del negozio | tabella `mpk` (per negozio e asset) | da definire con l'import di merchant e negozi (non ancora in `LegacyImporter`) |
| ID store BTCPay del negozio | `bps_storeid` dei negozi v1 (11 in produzione, lista utente 2026-11-16) | importato in `storesettings.bps_storeid` e nel collegamento di SIP-022: mai mostrato all'utente, evita store BTCPay doppi |
| Store "Iscrizioni Napoli Blockchain" | negozio v1 senza commerciante | è lo store delle quote associative: il suo ID va in `BTCPAY_STORE_ID` (env), non diventa un negozio di merchant |

Merchant, negozi e POS v1 non sono ancora importati: va deciso con SIP-022
(provisioning BTCPay) prima di attivare il punto 3 in produzione.

## Decisioni utente (2026-11-16)

1. Fino all'approvazione il socio **non entra**, come nella v1.
2. Iscrizione rifiutata: account **eliminato** dopo la mail con la motivazione;
   nel log resta solo la traccia, senza dati personali.
3. Promemoria automatico **30 giorni** prima della scadenza; la lista manuale
   resta a 45 giorni. **Niente** promemoria a chi non ha mai pagato.
4. Il socio **può disattivare** i promemoria dal proprio profilo.
5. Ordine dei lavori: 3 (wallet TTS per negozio), poi 1, poi 2, poi 4.

## Avanzamento

- 2026-11-16 punto 3 fatto (napay `7153bdd6`, pos `1735f95`): tabella
  `store_tts_wallets` con copia degli indirizzi per merchant su tutti i negozi
  e rimozione della tabella per merchant; pagina `store-wallet` e scheda
  "Wallet TTS" nel negozio; incasso POS sul wallet del negozio del terminale;
  saldo in dashboard come somma dei wallet dei negozi; tolto il pulsante
  morto del wallet BTC.
- 2026-11-16 punto 1 fatto (napay `e1e7c2c8`): stato di approvazione nel profilo
  socio, login bloccato fino all'approvazione, mail agli admin dopo la verifica
  dell'email, lista "Richieste di iscrizione" con approva/rifiuta (rifiuto con
  motivazione, account eliminato), soci v1 mai approvati importati in attesa,
  comando `membership/purge-unverified --once` (pianificazione con il worker
  del punto 2).

## Criteri di accettazione

- Nessuna registrazione senza email verificata in lista o nelle mail agli admin.
- Approvazione e rifiuto solo da admin, POST con CSRF, registrati nel log;
  il merchant della PG resta ad autoattivazione (SIP-023).
- Il promemoria automatico parte una sola volta per socio e scadenza anche
  con il comando rieseguito; i manuali rispettano la pausa minima.
- Ogni incasso TTS del POS va all'indirizzo del negozio del terminale;
  migrazione senza perdita degli indirizzi esistenti.
- Test su stack usa-e-getta per ogni passo; nessuna migration sulla sandbox
  condivisa senza autorizzazione.

## Impatto

- `napay`: registrazione, amministrazione soci, comando worker, negozi,
  `TtsPayments`, dashboard, migration nuove.
- `napay-project`: servizio worker per i comandi periodici.
