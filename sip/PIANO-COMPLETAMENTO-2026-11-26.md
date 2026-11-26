# Piano di completamento v2 - 2026-11-26

Approvato dall'utente come ordine di lavoro il 2026-11-26. Non costituisce
approvazione di retention, testi legali, spese, deploy o cancellazioni.
Stati ricavati da codice, SIP e registri locali; nessun controllo live delle VPS.

## Ordine e gate

| Ordine | SIP | Residuo | Gate di chiusura |
| --- | --- | --- | --- |
| 1 | 038 | Backup cifrati fuori macchina di A e C; recupero completo | Download, decifratura e ripristino usa-e-getta con confronto dei dati; errore upload visibile senza perdere backup locale |
| 2, parallelo | 040 | Pagine pubbliche privacy/condizioni/cookie, gestione versioni e consensi | Link anonimi funzionanti, autorizzazioni admin, versione accettata persistita; testi approvati dall'associazione prima della pubblicazione |
| 3 | 036 | Consolidamento produzione: autenticazione dominio posta, BTCPay rescan/webhook/chiavi/xpub, stato explorer, procedure | Evidenze correnti per ogni punto; modifiche VPS solo con consenso esplicito |
| 4 | 039 | Retention e richiesta cancellazione account, export e pulizia | Policy approvata, prove su account/merchant e contabilita; nessuna cancellazione automatica prima dell'approvazione |
| 5 | 004/020/021/022/023/030/033 | Regressione integrata ruoli, iscrizione, incassi, revoche, import | Flussi positivi/negativi su stack isolato, nessuna fuga tra merchant; BTC/PayPal produzione ancora non collaudati fino al pagamento |
| 6 | 031 | Completare analisi/contratto seed perso BTC; TTS gia presente | Blocco nuovi incassi e storico coerenti; test delle fatture in corso e recupero |
| 7 | 010 poi 037 | CI obbligatoria, poi deploy automatico | Test/lint/security gate, deploy serializzato, chiavi limitate, rollback provato |
| 8 | 018/026 | Uniformazione UI residua e grafici per ruolo | Scope delle aggregazioni, accessibilita e browser desktop/mobile |
| 9 | 029/027/024 | Web push e segnale chain a Napay, riallineamento motori | Riusare Go/SSE esistente ove pertinente; niente secondo listener senza esigenza approvata; REST resta autorevole |
| Separato | 028 | Nuovo token | Decisioni funzionali e verifica legale prima del codice |

## Chiusure trasversali, non nuove riscritture

- 002/003/016/019: Docker, TLS, deploy e persistenza presenti; confrontare ogni
  criterio con evidenze aggiornate prima di cambiare lo stato.
- 008/009/011: audit segreti, contratti API/schema e runbook verificabili.
- 005/007/012/015: aggiornamento del 26/11 gia registrato in SIP-015:
  store-wallet, bolt e tokenpay archiviati dall'utente; nessun loro porting.
  packages indicato senza consumatori v2: verificare e proporre archiviazione,
  senza eseguirla. Verificare assenza Yii1 nel runtime attivo prima di chiudere 012.
- 025 e 035 gia consegnati nel perimetro dichiarato; non riaprirli implicitamente.
- Explorer: compose presente nel checkout; handoff/registro discordanti sul
  deploy. Audit dipendenze candidato distinto dal servizio eventualmente attivo.
- SMTP: ultimo registro indica Brevo attivo, autenticazione dominio pendente;
  i vecchi handoff con sola posta su file non descrivono piu lo stato corrente.

## Assegnazione corrente

COD: SIP-038, orchestratore, branch feature/backup-offsite,
worktree /var/www/blockchain-napoli/napay-worktrees/backup-offsite.
Primo passo: cifratura locale e prove negative, nessun S3/VPS.

CLA: SIP-040 fase A solo Napay. Contratto e confini:
[SIP-040/PROMPT-CLA.md](SIP-040/PROMPT-CLA.md).
Nessuna modifica concorrente dei file orchestratore; consegna nel proprio
worktree Napay. Coordinamento tramite documents/COORDINAMENTO-AGENTI.md.

## Decisioni ancora necessarie

- S3: bucket/endpoint, permessi realmente disponibili, retention remota e
  custodia/recupero della chiave privata. Nessun segreto in chat.
- Privacy: testi, titolare/contatti, durate e basi da confermare; i valori
  proposti nei SIP non sono policy approvate.
- Accessi VPS, collaudi con denaro reale, dismissioni e deploy restano espliciti.
