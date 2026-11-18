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

## Seconda review A-C, 2026-11-12

Fix `842ea694` e test `704a9323` risolvono snapshot e revoca lato C4:
READ COMMITTED locale alla transazione, lettura corrente/lock delle sessioni,
ordine compatibile con login master `6487abbd`. Integrazione selettiva prevista
con `1c88626d`, `0463cbc6`, `842ea694`, `704a9323`, senza duplicare R1/snackbar.

Ulteriore caso da correggere dal master nell'integrazione: Scope::current
ricontrolla lo stato attivo del gestore tramite R1, ma non dell'admin
(User::isAdministrator verifica soltanto il ruolo). Se admin disattivato mentre
attende il lock merchant, scope ricalcolato puo ancora consentire la scrittura.
Guardia minima su account corrente attivo, senza modificare User/R1 globali;
regressione su admin disattivato durante attesa e nessuna scrittura persistita.
Prima di chiudere D3 serve inoltre gara con servizio C4 reale contro API master,
in due processi e in entrambi gli ordini, non solo simulazione SQL del protocollo.
Sidebar integrata solo con Scope disponibile; nessun riavvio o DDL condiviso.

Aggiornamento consegna agente: dipendenze `fef473f9`/`1a2f5d8a` (C2) prima di
R2/login sono uno scostamento corretto: sul master C2 era gia presente; nessun
nuovo cherry-pick delle copie R1/C2/R2/API. `bae55cdb` approvato: aggiunge lock
utente nelle concessioni, dopo il profilo e prima dei record dipendenti.
`b6b1653d` non importato: scenari gia coperti dalla suite congiunta master
`pos-management-sessions.php` con hook transazionali deterministici, senza
aggiungere una seconda implementazione della stessa gara. I test RV1/RV2
gia importati restano. Dopo il fix lock si rieseguono entrambi i runner C4.

## Chiusura A-C e D3 integrata

Stato finale master, 2026-11-12:

- Importati C4 `038591f6`, test `b27eb095`, fix RV1/RV2 `e1bad84c`, test
  `8a3c9cb4`, ultimo lock utente `2bc89049` (origine `bae55cdb`).
- Integrazione master `e0132f64`: guardia attivita admin, menu Terminali POS
  via Scope e runner congiunto C4/API. Nessun edit a C4-BACKOFFICE.md.
- Verificata identita esatta degli otto file di API `e54291b0` rispetto al
  master `6487abbd`; ordine dipendenze C2 -> R2 -> API confermato corretto.
- Eseguiti sul codice finale: **56 C4** (53 agente + menu/admin) e **59 C4/API**
  in due processi, con entrambi gli ordini, token non riattivabili, logout anche
  a profilo disabilitato, admin revocato durante lock e log senza segreti.
- Runtime completa gia rieseguita dopo integrazione di scope/menu: verde,
  incluso restart del web e bootstrap no-op. Sintassi PHP 8.3.36/shell e diff
  verificati. Nessun test grafico browser o migrazione/riavvio condiviso.

**A-C approvate e integrate; D3 sessioni chiusa.** Inviti D non implementati;
restano autorizzati alle condizioni dell'handoff R2/D3 e del contratto agente.
Non significa apertura esclusiva, sblocco POS, pagamenti o SIP-023 gia conclusi.
