# SIP-023 R3 - Iscrizioni, attivazione merchant e portale

Master, 2026-11-12. Requisiti gia confermati in SIP-023; micro-step R3a
implementato su richiesta dell'utente di proseguire. Nessuna modifica C4/B0.

## Sequenza e confini

1. R3a: registrazione pubblica esplicita PF/PG, profilo associativo atomico,
   nessuna autoassegnazione merchant/admin. Implementazione di questo turno.
2. R3b: autoattivazione del merchant dalla propria PG attiva, idempotenza e
   unicita gestore da progettare prima del codice; niente chiamata BTCPay
   sincrona e nessuna dipendenza dal vecchio settings.btcpayApiKey.
3. R3c: elenco/scheda soci e quote solo per identita associative coerenti;
   portale operatore senza associazione, enforcement server-side e menu.

R3b/R3c non implementati implicitamente da R3a. Il pagamento quote non e
incasso merchant; l'effetto di sospensione associativa sul commercio resta
indeciso. Nessuna nuova regola legale/tributaria dedotta dal tipo di profilo.

## Contratto R3a prima del codice

- SignupForm richiede `member_type` esattamente `pf` o `pg`, nome/cognome,
  email, password/conferma e i consensi associativi gia richiesti.
  Per PG nome/cognome restano quelli della persona referente dell'account;
  ragione sociale della PG separata in `denomination`, obbligatoria e max250.
- Nessuna scelta ruolo, `is_merchant`, `privilege_id`, `is_active` o user_id dal
  browser. Vecchio flag ignorato come campo non sicuro; senza tipo PF/PG
  esplicito la richiesta non crea account. Nessun fallback automatico a PF.
- Tutte le iscrizioni pubbliche creano soltanto account base (livello0 risolto
  dal catalogo privilegi, non ID fisso), `is_active=0`, `is_merchant=0`.
  Catalogo base assente/ambiguo = errore sicuro. Nessuna eccezione primo-admin:
  il provisioning admin appartiene a procedure amministrative separate.
- Creazione users e MemberProfiles nella stessa transazione (savepoint se
  chiamata nel controller gia transazionale). Consenso nella transazione
  esterna esistente. Errore profilo/consenso = nessun account orfano; email solo
  dopo commit. Riuso workflow attivazione/reset e normalizzazione UNIQUE R2.
- Profilo PF: is_corporate=0, denomination=NULL; PG: is_corporate=1 e ragione
  sociale valida. user_id deciso dal server; niente ruolo associativo,
  marker legacy, quote, merchant, store, operatore, grant o provisioning.
- Tipo e ragione sociale non sono parametri di attivazione email: il link
  attiva l'account esistente senza convertire profili o elevare privilegi.
- Riutilizzare MemberProfiles/schema esistenti, nessuna migration o backfill.
  Dati legacy e account gia iscritti restano invariati.
- Form Tabler esistente: sostituire scelta ordinario/commerciante con PF/PG,
  campo ragione sociale PG e indicazione attivazione merchant successiva.
  JS solo presentazione; validazione server autoritativa e form fruibile senza JS.
- Nessun consenso POS nel signup socio; flag POS forzato0 nella registrazione
  pubblica. Non cambiare documenti legali o consensi richiesti dalle altre funzioni.

## File e verifiche

Master: models/forms/SignupForm.php, controllers/SiteController.php,
views/site/signup.php, web/bundles/signup/selectorganization.js,
mail/newAccountAdmin.php (tipo PF/PG dal profilo, non flag merchant) e regressioni
activation/email. No edit Users/MemberProfiles/C4/B0 o API POS per questo passo.

Test dedicato: PF/PG, campi extra/escalation, tipo assente/array/ignoto,
ragione sociale PG vuota/lunga, rollback profilo e consenso, email duplicata e
race R2, registrazione senza ID1 che non crea admin, nessun record operativo,
mail file/attivazione che preserva tipo e ruolo, sintassi PHP/JS e runtime.
Dati solo fixture usa-e-getta; nessun seed, DDL o riavvio sandbox condivisa.

## R3a verificata

Signup PF/PG, transazione account/profilo e notifica admin aggiornati. Rimossa
scelta merchant/primo-admin; consensi non booleani rifiutati senza errori di
rendering. Corrette due condizioni negative emerse: denomination array e flash
con errori annidati su consensi mancanti (prima producevano 500).

Master ha eseguito: 116 controlli HTTP/DB/mail dedicati, 16 presentazione JS,
14 identita email, 68 reset, 92 attivazione, 24 policy e runtime completa con
restart/bootstrap no-op; sintassi PHP8.3.36/JS/shell e diff verificati.
I failure probe usano CHECK temporanei nel solo DB usa-e-getta, nessun SUPER,
trigger o allentamento FK; il caso senza ID1 usa tabelle clone vuote, non
cancella/rinumera righe legacy. Nessuna prova grafica browser in questo passo.
Nessuna migration R3a, conversione dati importati, quota o merchant automatico.

Implementazione R3a: commit Napay `d50ee879`. R3b/R3c ancora da implementare.
