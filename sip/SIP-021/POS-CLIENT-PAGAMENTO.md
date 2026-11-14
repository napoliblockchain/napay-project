# SIP-021 fase 3 - Client POS: porting dell'incasso dal POS legacy (APPROVATO)

Bozza 2026-11-14 (CLA master ad interim). Completa il
[contratto pagamento TTS](PAGAMENTO-TTS-CONTRATTO.md) lato `pos/v2`.
SIP-004 e il README di `pos/v2` indicano incasso, stato, storico e ricevute come
"non implementati" senza una mappatura: questo allegato la definisce.

## 1. Cosa faceva il POS legacy (Yii1, `pos/protected`)

| Funzione | Legacy | Note |
| --- | --- | --- |
| Tastierino | `keypad/index` (viste mobile/desktop) | Importo libero; due pulsanti: TTS e BTC (gateway del negozio). Avviso scadenza quota associativa. |
| Fattura TTS | `invoices/token` (AJAX) | Il browser inviava indirizzo wallet e `id_pos`; il server salvava la fattura in `np_pos_invoices` (scadenza dal negozio, default 15 min, tasso EUR), notifica push e avvio in background di `yiic receive`. |
| Fattura BTC | `invoices/btcpayserver` | Fattura BTCPay del negozio. |
| Pagina QR | `qrcode/index` | Merchant, POS, importo, conto alla rovescia, QR `indirizzo?amount=importo`, indirizzo copiabile; stati `new`, `paid`/`complete`, `paidPartial`, `paidOver`, `expired`. |
| Stato | `qrcode/getInvoiceStatus` | Polling AJAX dello stato salvato in DB. |
| Rilevazione | `commands/ReceiveCommand` | Processo per fattura, 1 s di attesa fino alla scadenza; abbinava il primo trasferimento verso l'indirizzo dopo la creazione, senza controllo di importo o riferimento. |
| Ricevuta | `keypad/printInvoice` | PDF A7 (TCPDF): negozio, indirizzo, P.IVA, data, importo, identificativo. |
| Storico | `tokens/index`, `tokens/view`, `transactions/index` | Elenco fatture TTS e BTC del wallet o dell'utente; dettaglio con mittente, destinatario e hash; "verifica" rilanciava `yiic receive`. |
| Altro | `messages`, `settings`, `site/contact` | Notifiche push, lingua, modulo contatti. |

Problemi da non riprodurre: indirizzo scelto dal browser, abbinamento senza
importo e riferimento, un processo per fattura, ID cifrati come unica protezione.

## 2. Corrispondenza in `pos/v2`

| Legacy | v2 | Stato |
| --- | --- | --- |
| Tastierino | Vista cassa esistente (importo in centesimi, validazione server) | Esiste in anteprima; il pulsante diventa "Incassa TTS". |
| Fattura TTS | `POST /openings/{id}/payments` dal server POS, con chiave di idempotenza in sessione | Backend pronto (Napay `c7ea3cdb`). |
| Pagina QR | Nuova pagina pagamento: importo, negozio/cassa, QR dal campo `qr`, scadenza, indirizzo copiabile | Da fare. QR generato lato server POS, nessuna libreria esterna nel browser. |
| Stato | Polling dal browser al server POS, che legge `GET /payments/{id}` | Da fare. Stati v2: `pending`, `paid`, `expired`, `cancelled` (niente parziale/eccedente: importo esatto). |
| Annulla | `POST /payments/{id}/cancel` | Da fare. Nuovo rispetto al legacy. |
| Ricevuta | PDF A7 generato dal server POS come nel legacy (TCPDF), stessi dati piu hash abbreviato | Da fare. |
| Fattura BTC | Fuori dalla fase 3 (SIP-022). | Pulsante non mostrato. |
| Storico | Richiede una lista nel backend (non esiste) | Proposta: fase successiva. |
| Messaggi, impostazioni, contatti | Non portati in fase 3. | — |

## 3. Regole del client

- Il browser non riceve mai token, apertura o chiave client: parla solo con il
  server POS (come aperture e catalogo).
- Il pagamento in corso e legato all'apertura nella sessione server; aperture
  revocate o scadute portano alla schermata di cassa con messaggio.
- Polling ogni 3 s solo mentre `pending` e la pagina e visibile; stop su stato
  finale o scadenza.
- PWA: nessuna pagina di pagamento o ricevuta in cache del service worker.
- Mobile-first: QR leggibile su schermo piccolo, pulsanti grandi.

## 4. Test previsti

Unitari del client (creazione, replay, stati, errori), pagina QR e ricevuta
senza dati sensibili, e2e reale POS -> gateway TLS -> Napay -> chain usa-e-getta
con transfer del pagatore di test, come `openings-e2e`.

## 5. Decisioni dell'utente (2026-11-14)

1. Ricevuta in PDF A7 come nel legacy (non pagina stampabile).
2. Storico incassi dopo il flusso di incasso (serve una nuova API di lista).

Libreria: `tecnickcom/tcpdf`, la stessa del legacy, usata anche per il QR in SVG
(nessuna libreria nel browser).

## 6. Stato implementazione (2026-11-14)

Repo `pos`, branch `feature/v2-pos-tts-client`, portato con fast-forward nel
main locale `feature/v2-yii2-php83-docker` (HEAD `688f0b1`, nessun push):
`e7dcbe8` ricevuta A7 e QR (tc-lib-pdf 8.84, tc-lib-barcode 2.17; metriche
Helvetica convertite una volta, nessun download in build), `0397dee` testi con
Yii::t e catalogo italiano, `71fa491` incasso dal tastierino, `688f0b1` test.

Verdi: client/controller simulati 49, importi 21, aperture 44, login 37,
logout 18, catalogo 37, config 13, PWA 30, contratto API e stato locale;
e2e reale con ruoli DB ristretti: pagamenti 17 + log (chain Besu usa-e-getta,
transfer reale), aperture 25 + log. Review non indipendente (stesso autore).

Restano: storico incassi (API di lista), sandbox locale (variabili TTS e rete
verso la chain in Napay, ricostruzione immagine POS) solo con ok utente.
