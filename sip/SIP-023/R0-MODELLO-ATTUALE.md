# SIP-023 R0 - Evidenze del modello attuale e gate condiviso

- Data: 2026-11-12. Autore/ownership: master.
- Solo analisi repository. Nessuna modifica al codice, SQL o dati.
- Decisioni funzionali: [SIP-023](../SIP-023-profili-soci-merchant-operatori.md).

## Evidenze verificate

| Area | Implementazione attuale | Conseguenza per i nuovi requisiti |
| --- | --- | --- |
| Soci | `Members extends Users`, senza scopo account persistente. | Un record users non prova l'iscrizione associativa. |
| Elenco soci | MembersSearch seleziona users con joinWith profile/privilege; non richiede profilo associativo e non esclude operatori. | Un futuro operatore puo apparire come socio: correggere query e conteggi prima del rilascio. |
| Scheda socio | AssociationController::actionMember ricerca per ID users senza condizione di appartenenza associativa. | Correggere anche deep link, non solo elenco. Controller resta admin-only: non e qui dichiarato un accesso pubblico. |
| Quote | MembershipFee ricava PG dal profilo; profilo mancante equivale oggi a PF. | Assenza profilo non prova socio PF; operatori/identita non classificate non devono ricevere quote per default. |
| Tipo PF/PG | MemberProfiles.is_corporate, user_id UNIQUE nella migration associazione. | Un solo profilo associativo per account, coerente con la cardinalita ora confermata; resta da distinguere lo scopo account e verificare il legame alla specifica PG. |
| Merchant | Merchants.user_id indica proprietario account; non esiste FK diretta da merchant alla specifica PG socia. | Proprietario e ruolo 30 non provano quale persona giuridica sia qualificata. |
| Registrazione | SignupForm accetta is_merchant e assegna il livello; possiede anche logica bootstrap primo-admin. | Non riusare signup() nel percorso invito e non far scegliere ruolo a chi accetta. |
| Email | SignupForm valida massimo 60 caratteri; users non ha indice univoco email nelle evidenze schema gia raccolte. | Invito VARCHAR(254) e validator non sono un contratto completo; evitare troncamenti e race con registrazione. |
| POS | C1 appartenenza/grant espliciti; C2 richiede base attivo e flag abilitati. | Buona separazione dei permessi, ma scopo socio/operatore e qualificazione PG richiedono controllo ulteriore. |

File letti: models/Members.php, MemberProfiles.php, search/MembersSearch.php,
forms/SignupForm.php, Merchants.php, controllers/AssociationController.php,
components/association/MembershipFee.php, migration associazione 100000 e C1.
Nessun dato personale o dump letto per questa ricognizione.

## Adeguamento da progettare prima del codice inviti

1. Definire esplicitamente scopo account e appartenenza associativa, senza
   usare solo livello 0/30 o il fatto che esista users. Dati non classificabili:
   riconciliazione esplicita, nessun permesso operativo inferito.
2. Definire legame merchant -> specifica PG socia e autorizzazione del gestore;
   non assumere che il profilo associativo del proprietario identifichi ogni PG.
3. Cardinalita ora confermata dall'utente: un account gestore per un merchant,
   nessun account gestore multi-PG/merchant. Definire vincoli e preflight per
   questa unicita sul modello esistente; censire i casi legacy non conformi.
   Nessuna scelta automatica del primo merchant o migrazione distruttiva.
4. Contratto unico di creazione/normalizzazione email e concorrenza per signup
   e accettazione invito. Il lock del singolo invito non serializza gli altri
   canali; non risolvere il problema con un semplice unique validator.
5. Gate applicativi su registrazione, inviti, elenco/schede/quote soci, gestione
   merchant e API POS. Il nuovo operatore non crea profilo o quota associativa;
   socio/gestore non acquisisce capacita POS nello stesso account.
6. Test dati legacy, account ambiguo, PF/PG, multi-merchant, email normalizzate,
   inviti concorrenti e assenza di regressioni su quote e sessioni.

Non sono qui decisi enum, nuove tabelle o backfill; richiedono il disegno
condiviso sulla cardinalita ora confermata. Non correggere dati importati per deduzione da nome,
P.IVA o livello privilegio. Nessuna modifica a migration gia applicate.

## Coordinamento C4

Timestamp 140000 rimane riservato agli inviti; non autorizzato DDL. L'agente C4
aggiorna il proprio contratto su nuovo account operatore tramite invito e sulle
email separate, proponendo le dipendenze condivise. Solo il master assegna
modifiche a Users/SignupForm, associazione e API; nessuna copia parallela dei
servizi identita per aggirare questo gate.

Per procedere indipendentemente: specifiche, viste, scope record-level e test
non dipendenti dalla nuova classificazione. Nessun allargamento dei privilegi
in produzione o creazione di profili soci/operatore finche il gate non e chiuso.
