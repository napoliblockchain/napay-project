# Canale asincrono master <-> agente Napay

Attivo dal 2026-11-12 su richiesta dell'utente (assente per alcune ore), per
proseguire senza passare dall'utente. Non sostituisce SIP, review e handoff:
li indica. Le regole di COORDINAMENTO.md restano valide.

## File

| File | Scrive | Legge |
| --- | --- | --- |
| `CODA-MASTER.md` | solo il master | agente Napay (controllo ogni ~20 minuti) |
| `RISPOSTE-AGENTE-NAPAY.md` | solo l'agente Napay | master |
| `STATO-AGENTE-NAPAY.md` | solo l'agente Napay | master |
| `STATO-MASTER.md` | solo il master | agente Napay |

## Stato dei lavori (per non pestarsi i piedi)

Ognuno tiene aggiornato il **proprio** file di stato a ogni inizio e fine
attività (un file a testa: stesso checkout, niente conflitti di scrittura):

- **In corso:** cosa, branch/worktree, da quando.
- **File che sto modificando adesso:** elenco esatto. L'altro non li tocca
  finché compaiono qui.
- **Risorse Docker in uso:** progetti/stack di test avviati (nomi), per non
  riavviarli o pulirli per errore.
- **Prossimo passo** e **in attesa di**.

Prima di modificare un file, leggere lo stato dell'altro: se il file compare
nel suo elenco, fermarsi e scrivere nella coda o nelle risposte.

## Formato di un incarico (in coda, in fondo al file)

```
## M-<numero> - <titolo breve>
- Stato: DA FARE
- Riferimenti: <review/handoff/SIP da leggere>
- Branch/worktree: <dove lavorare>
- Richiesta: <cosa fare, file autorizzati, test attesi>
```

Il master non modifica incarichi già presi: per correzioni aggiunge un nuovo
incarico che rimanda al precedente.

## Risposta dell'agente

```
## R-<numero dell'incarico> - <titolo>
- Stato: IN CORSO | FATTO | BLOCCATO
- Commit: <hash>
- Test: <eseguiti e non eseguiti>
- Note/blocchi: <cosa serve al master o all'utente>
```

## Limiti (l'agente si ferma e scrive BLOCCATO, senza procedere)

- push, merge o cherry-pick sul branch di integrazione;
- riavvio, migration o DDL sulla sandbox o sullo stack condiviso;
- produzione, chiavi reali, Internet per prove, provisioning reale;
- modifica di file del master o condivisi senza assegnazione esplicita;
- cancellazioni o comandi distruttivi su risorse non create dall'agente;
- decisioni funzionali dell'utente non ancora prese.

Quando non ci sono incarichi nuovi, l'agente prosegue il lavoro già
autorizzato nel proprio ultimo handoff e lo dichiara nelle risposte.
