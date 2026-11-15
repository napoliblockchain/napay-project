# SIP-029 - Wallet realtime: indicizzatore della chain e push (Go)

- Stato: APPROVATO (decisioni utente 2026-11-15), in sviluppo per passi
- Area: Wallet / Blockchain / Notifiche
- Repo: `poawallet` (servizio in `poawallet/realtime`), `napay-project` (compose, launcher)
- Branch target: `feature/v2-yii2-php83-docker` (poawallet)

## Contesto
Il wallet legge i dati con tre cicli dal browser: `blockchain/ethtx` ogni 6 s,
`blockchain/check-latest` ogni 10 s, `backend/notify` ogni 5 s. Il primo chiede a
PHP di trasformare in transazioni dell'utente le righe della tabella `ethtxs`, che
dovrebbe riempire un demone systemd (`daemons/EthereumTransactions.php`) non
presente nello stack Docker: nella sandbox `ethtxs` e `ethtxs_status` sono vuote,
i pagamenti in arrivo non compaiono in Transazioni e lo stato di
sincronizzazione resta sconosciuto (pallino grigio). Esiste in parallelo
`ws-notify` (Node, WebSocket + Redis) per le notifiche, con porta sull'host.

## Decisioni
- Un solo servizio Docker `wallet-realtime`, scritto in **Go** con `go-ethereum`
  (libreria ufficiale della chain): un eseguibile, immagine minima, nessuna catena
  di pacchetti npm, concorrenza adatta a molte connessioni push.
- Lettura della chain sul server (indicizzatore), aggiornamenti al browser in
  **push SSE** (Server-Sent Events) al posto dei tre cicli.
- Napay resta indipendente: verifica i pagamenti da sé (vedi integrazione futura).

## Architettura
### Indicizzatore (passo 1)
- Chain e RPC solo da configurazione (`CHAIN_RPC_URL`, `CHAIN_ID`): mai URL RPC
  presi dal database, che sono scelti dagli utenti (rischio SSRF). Chain id
  verificato a ogni giro.
- Contratti: token scelti dagli utenti (`nodes` → `smart_contract`) su quella
  chain, raggruppati per indirizzo.
- Eventi `Transfer` letti con `eth_getLogs` per intervalli di blocchi, con un
  cursore per contratto (`chain_index_cursors`) aggiornato nella stessa
  transazione dei dati: ripresa senza perdite né doppioni dopo riavvii o errori.
  Conferme configurabili (QBFT ha finalità immediata: 0 in sviluppo).
- Per i wallet registrati (`mp_wallets`): riga nuova in `transactions` per i
  trasferimenti in arrivo; invio fatto dal wallet (riga già creata da PHP con lo
  stesso hash) portato a `complete`; nessun doppione sull'hash (lock della riga).
- Notifiche in `mp_notifications` / `mp_notifications_readers` con gli stessi
  testi di PHP (`NotificationService`); le notifiche web push restano a un passo
  successivo.
- Invii rimasti in attesa ma falliti sulla chain (ricevuta con stato 0): `failed`.
- Utente MySQL dedicato con i soli permessi necessari (lettura di wallet, nodi,
  contratti, reti; scrittura di transazioni, notifiche e cursori); password da
  file (secret Docker), mai nei log; nessuna chiave privata nel servizio.

### Push SSE (passo 2)
- `wallet.local/events` instradato dal gateway al servizio.
- Accesso con cookie firmato (HMAC) a breve scadenza emesso da PHP alla pagina:
  HttpOnly, Secure, SameSite=Strict, Path=/events; nessun token nell'URL.
- Eventi: nuova transazione, saldo, notifiche non lette, stato della rete
  (blocco della chain, ritardo dell'indicizzatore); segnale periodico di vita.
- Browser: `EventSource` con riconnessione automatica; la riga della transazione
  resta generata e codificata da PHP. Pallino: verde se connesso e indicizzatore
  al passo, giallo se in ritardo, rosso se la connessione cade.
- Limite di connessioni per utente; un'istanza (Redis solo se più istanze).

### Pulizia (passo 3)
- Rimossi: i tre web worker del browser, gli endpoint PHP `blockchain/ethtx` e
  `blockchain/check-latest`, `ws-notify`, il demone `EthereumTransactions.php`
  e la tabella `ethtxs` se non più usata.

## Integrazione futura con Napay (SIP-027)
- L'indicizzatore potrà avvisare Napay quando vede un `Transfer` verso
  l'indirizzo di un merchant ("trasferimento verso X nel blocco N, transazione
  H"), tramite un endpoint interno autenticato.
- **Napay non si fida dell'avviso**: lo usa solo come segnale per verificare
  subito quel pagamento sulla chain con le regole della fase 3 (destinatario,
  importo, riferimento, scadenza). L'avviso non cambia mai uno stato da solo.
- Il POS mostrerebbe "Pagato" all'istante; il controllo periodico attuale resta
  come ripiego se l'avviso non arriva.

## Criteri di accettazione
- Nessun trasferimento perso o duplicato dopo riavvio, errore RPC o DB.
- Nessun URL RPC dal database; nessun segreto nei log; container non root.
- Test: unitari Go (lettura eventi, idempotenza) e integrazione su MySQL e Besu
  usa-e-getta con trasferimenti reali, prima di ogni passo in sandbox.

## Stato
- 2026-11-15: decisioni prese; passo 1 in sviluppo.
