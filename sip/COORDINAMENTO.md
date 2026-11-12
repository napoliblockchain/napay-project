# Coordinamento Napay / POS - obiettivo 23 novembre 2026

- Responsabile integrazione: agente master di questa sessione.
- Agente Napay: backoffice e relativi test, solo file assegnati sotto.
- Priorita: chiudere flussi completi e collaudati, non dichiarare production-ready
  software che ha superato solo una demo o test simulati.
- Regola invariata: SIP prima del codice, piccoli commit, nessuna modifica ai
  file dell'altro senza handoff esplicito.

## Canale e ownership

Tra sessioni indipendenti non e disponibile qui un canale diretto identificato.
Usare questo registro e gli handoff versionati; il prompt trasferisce all'altro
agente l'incarico. I subagent creati dal master possono invece ricevere messaggi
tramite gli strumenti della sessione. Non dichiarare messaggi inviati a sessioni
esterne quando non lo sono.

Questo file e SIP-021/SIP-022 sono scritti dal master. L'agente Napay scrive solo
`sip/SIP-021/C4-BACKOFFICE.md` e `sip/SIP-021/C4-HANDOFF.md` come allegati propri.
Il master recepisce decisioni/esiti negli indici/SIP. Prima di ogni incarico
registrare branch, base commit, file riservati e test; se un file necessario
appartiene all'altro agente, proporre la modifica nell'handoff, non editarlo.

Per Napay usare branch e worktree separati: branch diversi nella stessa cartella
non isolano il filesystem. Il worktree di sviluppo non e il bind mount della
sandbox condivisa. Niente symlink di vendor/runtime/segreti verso il worktree
principale; eventuale ambiente test del secondo agente deve essere indipendente.
La creazione di un worktree non autorizza nuovi stack o l'uso del DB condiviso.

## Ripartizione iniziale

Regole trasversali aggiornate: [SIP-023](SIP-023-profili-soci-merchant-operatori.md).
Solo PG socia diventa merchant; gestore non opera POS; operatore non socio.
Stessa persona socio/operatore: due account e due email. Il livello "base" da
solo non distingue questi scopi. Agente C4 recepisce nelle proprie specifiche;
master riserva disegno/integrazione di eventuali adeguamenti condivisi.
Review C4 (documenti 11877b1/18246fe): inviti non ancora approvati per differenze
con SIP-023. Timestamp 140000 riservato all'agente Napay, non autorizzato DDL.
Agente aggiorna C4-BACKOFFICE/C4-HANDOFF; master definisce qualificazione PG e
scopo account condivisi. Le concessioni non possono usare il solo livello 0/30.
Ricognizione del master pronta: [R0 identita](SIP-023/R0-MODELLO-ATTUALE.md).
Include le query soci/quote e l'assenza del legame diretto merchant-PG;
cardinalita confermata: un gestore dedicato per merchant, nessun account gestore
multi-PG/merchant. Ogni merchant crea solo i propri operatori POS. Vecchi casi
multi-merchant per account richiedono riconciliazione, non uso di merchants[0].

C1 chiuso: Napay `c357ec41`, `a3fd15f3`; [handoff](SIP-021/C1-HANDOFF.md).
Agente Napay assegnato a `feature/v2-napay-backoffice-c4`, worktree
`/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`, base `a3fd15f3`.
Incarico immediato: [prompt C4](SIP-021/PROMPT-AGENTE-NAPAY.md).
C2/C3 chiusi: [handoff catalogo](SIP-021/C2-HANDOFF.md). Napay `7ee57669`,
`0275704f`; POS `74e0287`, `90fd41e`. Il master passa al contratto aperture;
backoffice resta all'altro agente, nessuna apertura abilitata dal catalogo.
Contratto C4 revisionato: [approvazione parziale](SIP-021/C4-APPROVAZIONE.md).
Terminali, profili/grant e revoca D3 possono procedere. D1-D3 confermate:
invito merchant con consenso e completamento profilo, solo account base attivi,
revoca sessioni al disable. Prima del codice inviti serve allegato tecnico e
risoluzione delle collisioni email/registrazione, come nell'approvazione C4.

| Area | Responsabile | Confine |
| --- | --- | --- |
| C1 schema/modelli | Master | Migration 130000, tre AR e test dedicati; integrazione centralizzata. |
| C2 catalogo API e C3 vista POS | Master | `modules/posapi`, `components/pos/TerminalCatalog.php`, repo POS e test API. |
| Apertura esclusiva, heartbeat/revoca, API pagamento TTS | Master | Prima contratto SIP, poi servizi/API/migration riservati. Nessun lock lato solo browser. |
| C4 backoffice terminali/operatori/grant | Agente Napay | Prima allegato C4 e handoff; poi controller/form/view/service nuovi, senza cambiare AR C1 o API. |
| Provisioning BTCPay SIP-022 | Agente Napay dopo C4 | Prima B0 versione/permessi/identita tecnica; nessuna implementazione finche aperti quei punti. |
| Rotte condivise, layout/menu, runner, stack, ordine migration | Master integra | Secondo agente consegna patch richiesta nell'handoff; niente edit o riavvii concorrenti. |

Non recuperare il modello legacy Pos mancante per aggirare i nuovi modelli.
`PosApi.php`, `Throttle.php`, Users/Stores/Merchants restano dipendenze condivise:
qualsiasi modifica richiede nuova assegnazione esplicita del master.

## Piano di lavoro e gate

Date = obiettivi operativi, non garanzia di rilascio senza accettazione.

| Data | Master | Agente Napay / gate |
| --- | --- | --- |
| 12/11 | Chiudere C1, verifica schema gia applicato, commit e worktree separato | Leggere handoff C1; preparare C4 e segnalare regole gestionali mancanti. |
| 13-14/11 | Definire/implementare C2-C3 e collaudo catalogo autorizzato | C4 approvato e implementato su file propri; nessuna assegnazione cross-merchant. |
| 15-16/11 | Apertura esclusiva, revoca e prove concorrenti su DB reale di test | Backoffice sblocco manager solo dopo contratto master, UI/azioni protette. |
| 17-18/11 | Primo flusso TTS locale: richiesta, QR, stato; nessun denaro reale | B0 BTCPay e provisioning se approvato; evidenziare blocchi di istanza/credenziali. |
| 19-20/11 | Integrare esiti, storico/ricevuta minima e gestione rete/timeout | Regressioni Napay, provisioning e ownership remota in ambiente di test. |
| 21-22/11 | Freeze funzionale, sicurezza/tenant/CSRF, recovery, persistenza e documentazione | Zero regressioni gravi, handoff e bug riproducibili; niente nuovi ambiti. |
| 23/11 | Collaudo con utente e decisione di accettazione | Rilascio solo del perimetro verificato; blocchi espliciti, mai nascosti. |

## Accettazione proposta per il 23/11

- Stack Docker ripetibile, persistenza DB e bootstrap/import controllati; login,
  email/password e flussi Napay concordati senza regressioni gravi.
- Operatore di un solo merchant, grant espliciti a piu suoi negozi, catalogo
  filtrato; secondo dispositivo non apre POS occupato, sblocco solo manager
  autorizzato e vecchia apertura immediatamente inutilizzabile.
- Primo pagamento TTS su chain locale con destinazione merchant risolta dal
  backend, importo/idempotenza/stato verificati, esito e ricevuta minima coerenti.
- Provisioning BTCPay automatico verificato su istanza di test se B0 risolto:
  utenti distinti per merchant, store/POS corretti, retry e ownership dimostrati.
- Nessuna promessa di incassi produzione, compliance o copertura di qualunque
  vecchia pagina non censita: eventuali scostamenti vanno concordati col cliente.

## Blocchi e escalation

Dipendenze ancora da chiudere: contratto pagamenti/wallet TTS, chain e token di
collaudo, semantica lock/fencing, contratto GET e C4, istanza BTCPay di test,
identita tecnica distinta per merchant e privilegi provisioning. Identificarle
entro 13/11; se non risolte entro 16/11, rivedere esplicitamente perimetro/date.
Test simulati non sostituiscono un backend reale, ne un esito remoto ambiguo
puo essere dichiarato riuscito. Trasferimenti tra merchant e wallet per negozio
restano fuori dal perimetro attuale.

## Integrazione

Ogni handoff contiene commit, file, test eseguiti/non eseguiti e rischi. L'agente
secondario non fa merge/cherry-pick sul branch di integrazione. Il master
riesamina i commit, integra e riesegue le regressioni pertinenti. Nessuna
migrazione/riaccensione della sandbox condivisa senza suo via libera.
