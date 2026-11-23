# SIP-036 - Rilascio della v2 sulla VPS e passaggio dalla v1

- Stato: IN_PROGRESS
- Area: Rilascio / DevOps
- Repo: orchestratore, `napay`, `pos`, `poawallet`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-23 (richiesta utente: arrivare a qualcosa di pubblicabile)

## Contesto
Le funzioni v2 (backoffice, POS, wallet, BTCPay, import dalla v1) sono
testate in sandbox e su stack usa-e-getta, ma per la VPS esiste solo il
rilascio del wallet (`deploy-wallet.sh`). La composizione dell'orchestratore
punta ancora al POS legacy e all'immagine di sviluppo di Napay. Il POS v2
accetta solo la modalità "preview" (chain di test). Non c'è una procedura
del passaggio scritta e provata.

## Parti

| Parte | Cosa | Chi |
| --- | --- | --- |
| A | Napay in produzione: immagine versionata, web, cron, worker BTCPay, bootstrap/import, script di rilascio con controllo, ritorno alla versione precedente | CLA (master) |
| B | POS v2 in produzione: modalità produzione nell'app, composizione e script di rilascio | COD ([incarico](SIP-036/PROMPT-AGENTE-COD.md)) |
| C | Orchestratore: gateway e certificati dei domini reali, reti, backup del database v2 | CLA |
| D | Procedura del passaggio (fermo v1 1-2 ore, variabili, logo, webhook, ritorno alla v1) | CLA |
| E | Prova generale dell'import su copia fresca del DB di produzione | CLA + utente |

## Regole
- Segreti solo in file privati 0600 fuori dai repository; nessun valore nei
  log o nell'output; nessuna porta pubblicata oltre al gateway.
- Ogni script ha una modalità di solo controllo che non costruisce e non avvia.
- Migration automatiche al rilascio; se falliscono resta in servizio la
  versione precedente.
- Nessun rilascio sulla VPS senza ok esplicito dell'utente.

## Criteri di accettazione
- Rilascio ripetibile da una cartella pulita con il solo file env privato.
- Prova generale: import completo e riconciliazione verdi sulla copia fresca.
- Procedura del passaggio scritta, con tempi e passi di ritorno alla v1.
