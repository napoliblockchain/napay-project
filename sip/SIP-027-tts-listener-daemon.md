# SIP-027 - Listener continuo dei pagamenti TTS (evoluzione futura)

- Stato: OPEN
- Area: Pagamenti / Blockchain
- Repo: `napay`, `napay-project`
- Branch target: `feature/v2-*`
- Segnalato: 2026-11-14

## Contesto
La fase 3 di SIP-021 ([contratto](SIP-021/PAGAMENTO-TTS-CONTRATTO.md)) rileva i
pagamenti TTS solo quando il POS chiede lo stato, piu un comando one-shot per le
scadenze. E la scelta approvata per il collaudo locale: nessun processo sempre
attivo. Limiti noti: la conferma arriva solo al successivo polling, un POS chiuso
lascia la richiesta in attesa fino al comando one-shot, ogni lettura stato
interroga l'RPC.

## Proposta
Valutare un servizio dedicato che segue i nuovi blocchi della chain (sottoscrizione
ai log Transfer del contratto TTS, con ripresa da un checkpoint persistito) e
applica le stesse regole di abbinamento del contratto di fase 3. Il POS
riceverebbe l'esito via notifica (vedi SIP-024) invece del solo polling.

## Criteri di accettazione
- Stesse regole di abbinamento e stessi stati della fase 3, nessuna regola nuova.
- Ripresa senza perdite dopo riavvio, riorganizzazioni o RPC non disponibile.
- Un solo listener attivo per istanza; nessuna chiave privata nel servizio.
- Polling del POS ancora funzionante come ripiego.

## Impatto
- Nuovo servizio Docker con accesso RPC in sola lettura, checkpoint su DB Napay.
- Integrazione con il motore notifiche di SIP-024.

## Note implementative
- Da riprendere solo dopo il collaudo della fase 3 e con nuova approvazione.
- Valutare carico e alternative (sottoscrizione websocket o polling dei blocchi).

## Aggiornamento 2026-11-15: ascoltatore condiviso con il wallet
Il servizio `wallet-realtime` di [SIP-029](SIP-029-wallet-realtime-indicizzatore-push.md)
(Go, `go-ethereum`) legge gia gli eventi `Transfer` dei token. Quando questo SIP
verra ripreso, l'ascoltatore di Napay sara quel servizio, non un secondo processo:
- avvisa Napay di un trasferimento verso l'indirizzo di un merchant (blocco,
  transazione) con un endpoint interno autenticato;
- Napay non si fida dell'avviso: verifica subito quel pagamento sulla chain con
  le regole della fase 3 e solo cosi cambia stato;
- il controllo periodico del POS e il comando one-shot restano come ripiego.

