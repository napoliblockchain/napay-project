# C4 A-C e D - Review master, 2026-11-12

Commit esaminati: Napay `1c88626d`, `0463cbc6`; documenti `cdd680c`,
`6fa35ca`. I cherry-pick `7ca815cf`/`dff150e3` sono la policy R1 gia
integrata dal master: non sono ulteriori commit C4 da importare.

## Esito

**Integrazione A-C sospesa per correzioni concorrenti; non rifiutato il disegno.**
Scope query, CSRF/POST, encoding, allowlist dei campi, gate R1 e riduzioni
sono coerenti col contratto. Il master ha rieseguito `pos-management.sh`
nel worktree C4: 49 PASS e bootstrap no-op, DB/container usa-e-getta.
Nessun test grafico e nessuna regressione completa rieseguita dal master;
i risultati aggiuntivi dell'agente restano dichiarazioni del suo handoff.

## Finding e assegnazioni

### C4-RV1 - P1: snapshot precedente al lock merchant

`components/pos/management/PosManagement.php:150,164,175`: le SELECT non
locking prima di `lockMerchant` aprono lo snapshot InnoDB. Con REPEATABLE READ,
la policy richiamata alla riga 143 puo leggere l'ownership precedente anche
dopo avere acquisito il lock sulla riga merchant aggiornata. Rileggere la
policy dentro la transazione non equivale a una lettura corrente.

Agente C4: correggere sulle proprie classi, senza duplicare R1 e senza
modificare policy/configurazione DB globale. Dimostrare con due connessioni
che cambio titolare o revoca dei requisiti committati prima dell'acquisizione
lock impediscano la scrittura. Definire isolamento/ordine lock espliciti e
compatibili con gli altri writer; non limitarsi a spostare una SELECT.
Il test attuale cambia profilo prima dell'inizio della transazione e non
riproduce questa finestra. Consegna fix e test in commit piccoli.

### C4-RV2 - P1: D3 e creazione sessioni non serializzate

`PosManagement.php:70` enumera sessioni senza protocollo condiviso col login.
`modules/posapi/controllers/SessionsController.php:95` e
`components/pos/PosApi.php:91` creano sessioni senza lock del profilo POS.
Login durante la disabilitazione, o dopo enumerazione, puo lasciare un bearer
non revocato; riabilitare il profilo gli restituisce accesso senza nuovo login.
Non e sufficiente un update massivo o una lettura corrente delle sessioni.

Master: riservati API login/PosApi e relativi test per integrare R1 e controllo
profilo abilitato, con validazione/inserimento atomici rispetto al disable.
Agente C4: mantiene lock del profilo fino a commit della revoca; deve allineare
l'ordine lock col master e testare revoca su letture correnti, senza perdere
sessioni committate dopo lo snapshot iniziale. Non modifica API o PosApi.php.
Gate finale: login contro disable, profilo gia disabilitato e riabilitazione;
nessun vecchio token torna utilizzabile. Per ora nessuna dichiarazione D3 chiusa.

## Parte D e unicita email

Flusso invito approvato come disegno: nuovo account dedicato, niente riuso di
soci, token digest/72h/monouso, GET non consuma, POST CSRF, profilo disabilitato
e senza grant. **Codice D e DDL restano bloccati dalla dipendenza email.**

Decisione master: soluzione definitiva con colonna normalizzata generata e
indice UNIQUE in `users`, non ponte GET_LOCK. Prima audit di duplicati, valori
vuoti e compatibilita collation/lunghezze; mai fusione, cancellazione o riscrittura
silenziosa degli account legacy. Anomalie = stop con riconciliazione esplicita.
Normalizzazione coerente tra SQL, validator, policy e inviti, incluse varianti
maiuscole/spazi; testare le collisioni reali del DB. Pubblica registrazione e
inviti devono gestire la violazione UNIQUE senza esporre dettagli SQL.
Limite applicativo email 60; non dedurre da questo la lunghezza fisica attuale.

Master riserva implementazione e migration condivisa utenti, da documentare
prima del codice. `m261112_140000_create_pos_operator_invitations.php` resta
riservata all'agente, non ancora autorizzata. Niente inviti sulla sola promessa
che un indice verra aggiunto. Reinvio/notifiche per email gia esistente devono
rispettare i limiti anti-abuso, non solo l'invio di nuovi token.

## Integrazione condivisa

Sidebar proposta corretta, ma patch rinviata all'integrazione A-C corretta;
nessun collegamento a controller non ancora integrato. Runner dedicato confermato.
Fix snackbar `5a39d763` gia integrato come `6967b7b5`: non ripetere il cherry-pick.

## Verifica indipendente C4-RV1

Il master ha eseguito anche una sonda temporanea su secondo stack usa-e-getta:
isolamento effettivo `REPEATABLE-READ`; transazione A apre snapshot, connessione
B cambia proprietario e committa, A acquisisce lock merchant e richiama il gate
reale `lockMerchant`. Esito: **scope del vecchio gestore accettato**.
Sonda di regressione ad hoc, non ancora aggiunta alla suite versionata; nessuna
modifica al codice C4 o alla sandbox. Conferma il finding, non testa una fix.

Protocollo lock da usare per C4/API D3: merchant, poi profilo operatore, poi
sessioni, nella stessa transazione. Identificativi risolti prima dei lock sono
solo hint: rileggere appartenenza e autorizzazioni nello stato corrente sotto
lock. Login inserisce sessione solo dopo controllo profilo attivo/R1; disable
mantiene lock fino a revoca e commit. L'isolamento adottato deve rendere visibili
le sessioni gia committate quando il disable acquisisce il lock. Il master
implementa lato API; l'agente puo correggere C4 e testarne il proprio lato senza
modificare API o attendere una modifica a PosApi.php.
