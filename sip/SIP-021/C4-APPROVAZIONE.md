# C4 - Approvazione master, 2026-11-12

Revisionati C4-BACKOFFICE.md e C4-HANDOFF.md. Confine file e impianto tecnico
approvati: controlli record-level, scope prima dei conteggi, CSRF/POST, nuovi
form/service/controller/view, C1 invariato, nessun delete/trasferimento/lock.

## Via libera immediato

**Precisazione successiva, prevalente: review dei documenti 11877b1 e 18246fe.**
Il disegno generale e riusabile, ma il contratto inviti **non e approvato**
finche non recepisce SIP-023. Il precedente via libera su profili/grant non
autorizza a concedere operativita ad account soci di livello 0 o a merchant
privi di qualificazione PG. Possono proseguire parti indipendenti, strutture UI,
scope e controlli di sola riduzione dei privilegi; le concessioni e il flusso
inviti richiedono prima il contratto aggiornato e le dipendenze condivise definite.

Agente Napay puo implementare servizi comuni di scope, elenco/creazione/modifica
nome/abilitazione terminali e relativi test nel worktree assegnato. Non occorre
attendere D1-D3 per questa parte. Nessuna riga profilo/grant creata implicitamente.
Non aggiungere menu o modificare file master: consegnare richiesta nell'handoff.

## Decisioni utente recepite (2026-11-12)

- D1: il merchant inserisce email del nuovo operatore; il sistema invia un
  invito. Il destinatario accetta tramite link e imposta password/conferma,
  nome e cognome. Altri dati solo se necessari; non introdurre campi superflui.
  Non e approvato il collegamento admin senza consenso proposto in D1-A.
- D2: soltanto account base attivi. Il titolare usa un account base distinto
  per operare alla cassa. C2 applica questo controllo anche alla lettura API.
- D3: disabilitare il profilo revoca le sessioni POS esistenti nella medesima
  transazione; riabilitare non le riattiva, serve nuovo login.

Via libera anche a gestione profili gia presenti, grant e disable/revoca D3
secondo queste decisioni e sul write set C4 gia riservato. Non usare un link
di invito per sovrascrivere password o rivendicare un account gia registrato.

## Inviti: prossimo allegato tecnico prima del codice

Vincolo trasversale confermato successivamente:
[SIP-023](../SIP-023-profili-soci-merchant-operatori.md). Solo PG socia diventa
merchant; gestore non usa POS. Un operatore non diventa socio per invito.
Socio che vuole operare: altro account e altra email; vietato riusare email o
account associativo anche se ha livello tecnico base. Aggiornare C4-BACKOFFICE
e C4-HANDOFF prima del codice dipendente da questa separazione. Non dichiarare
gia implementata la distinzione sulla sola base di C1/C2; niente edit autonomi
a Users/SignupForm, AR C1 o API condivise.

Correzioni richieste alla versione C4 esaminata:

1. Non chiedere una registrazione pubblica generica prima di accettare l'invito.
   Il nuovo operatore completa direttamente il percorso invito con password,
   conferma, nome e cognome. Nessuna iscrizione associativa automatica.
2. Livello 0 e account attivo non bastano: verificare scopo account operatore
   e assenza di riuso dell'account socio/gestore. Email gia socio = altra email,
   non collegamento dopo login. Stessa persona puo avere entrambi solo separati.
3. Merchant eleggibile solo se PG socia con relazione verificata server-side;
   non bastano livello 30 e riga merchants. Il master definisce l'adeguamento
   condiviso; niente riconoscimenti automatici basati su nomi/partita IVA.
4. FOR UPDATE sul singolo invito non risolve collisioni email tra inviti diversi
   e registrazione pubblica. Contratto deve esplicitare serializzazione/unicita,
   normalizzazione e fallimento sicuro senza duplicare utenti o cambiare password
   esistenti. Allineare anche i limiti email ai validator/schema effettivi.

Timestamp **riservato all'agente Napay**:
`m261112_140000_create_pos_operator_invitations.php` (tabella additiva inviti).
La riserva evita collisioni, **non autorizza ancora codice migration o DDL**:
prima contratto/schema corretto e review master. Runner dedicato
`tests/docker/pos-management.sh` confermato; sidebar integrata dal master solo
dopo consegna codice/test e patch richiesta. Nessun edit a tabelle C1.

Precisazione utente sulla cardinalita, ora confermata in SIP-023: unico account
gestore dedicato a un solo merchant; tanti merchant indipendenti, ciascuno con
i propri operatori. Il gestore puo creare soltanto account POS tramite invito,
non soci, altri gestori o nuovi merchant. Aggiornare C4: la ricerca di tutti i
merchant con user_id uguale non autorizza a mantenerli come scope gestionale.
Caso legacy con piu righe: errore/riconciliazione sicura, mai merchants[0] o
estensione implicita dello scope. Il master definisce gli adeguamenti condivisi.

Aggiornare C4-BACKOFFICE.md con la scelta D1 e proporre schema/contratto inviti:
token casuale, solo digest nel DB, scadenza, monouso/consumo atomico, revoca e
rate limit; GET visualizza il form senza consumare, POST con CSRF completa.
Creazione definitiva account base e appartenenza solo dopo consenso verificato,
transazionali, senza grant o abilitazioni implicite in violazione di C1.

Riservati all'agente Napay per la proposta (non ancora via libera al DDL):
`migrations/m261112_140000_create_pos_operator_invitations.php`,
`models/PosOperatorInvitations.php`, `controllers/PosInvitationController.php`,
form/service/view/test dedicati sotto le aree C4. Niente edit a SignupForm o Users.

Da consegnare al master prima del codice inviti: email gia esistente o ambigua,
collisione con registrazione pubblica/accettazioni concorrenti, inviti di merchant
diversi e gestione email fallita/reinvio. L'attuale schema utenti non garantisce
unicita DB dell'email: non dichiarare risolta la concorrenza con un semplice
findOne/validator. Eventuali hook nel flusso di registrazione condiviso li
assegna/integra il master. Password/hash e ruoli devono riusare le primitive
centrali sicure, non la scelta pubblica is_merchant o la logica primo-admin.
Test mail su file; mai token/password nei log o in risposte al merchant.

## Precisazioni vincolanti

- Selezione di un merchant da parte dell'admin puo arrivare dal form come ID
  cifrato/validato; e solo selettore. Servizio risolve il record in scope e
  determina merchant_id, mai mass assignment su AR da POST.
- Nei log errori nessun dump eccezioni/query/POST/sessione o credenziali: solo
  classi/codici sicuri; audit dei nomi con Log::quote secondo contratto.
- Ownership merchant ricontrollata dentro la transazione e sotto lock prima
  della scrittura; non riusare ciecamente un modello letto prima del lock.
- L'eventuale revoca D3 riguarda sessioni gia persistite, nella stessa
  transazione del disable; nessuna promessa di disabilitare il login dell'account
  Napay. C2 ricontrolla comunque profilo/grant a ogni richiesta.
- Test CRUD non devono usare sandbox condivisa, chiamate finanziarie o dati reali.

Aggiornare solo C4-HANDOFF.md/C4-BACKOFFICE.md e i file di codice riservati.
Il master continua C2/C3 e integra menu/rotte solo dopo review dei commit C4.
