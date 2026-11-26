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

## R3c-0 - Risoluzione condivisa del merchant

Prerequisito minimo indipendente da R3b: User::getMerchantId non deve piu
selezionare merchants[0]. Riusare AccountEligibility::merchantForManager
per l'account corrente: solo gestore attivo, unico merchant e PG coerente.
Guest/identita assente, operatore, socio, admin, duplicati o conflitti email
restituiscono0, compatibile con il filtro esistente stores.merchant_id.
Nessun fallback a merchant arbitrario o dati non filtrati; errori schema
propagati, non convertiti in autorizzazione. Nessuna scrittura o migrazione.

File master: components/User.php e tests/application/account-eligibility.php.
Test con session identity gia caricata, poi disabilitazione/conflitto nel DB:
la policy deve rileggere stato aggiornato. Restano da completare R3b, portale
R3c e verifiche record-level degli altri controller: questo helper non e
una dichiarazione di sicurezza di tutte le rotte legacy.

R3c-0 verificata:32 controlli policy/helper nel DB usa-e-getta e runtime
completa, incluso riavvio con dati preservati/bootstrap no-op, tutti verdi.
Sintassi PHP8.3.36 e diff controllati. Nessuna prova grafica browser o nuova
migration. La mancata qualificazione di dati legacy ora nega la selezione
implicita del merchant: richiede riconciliazione, non scelta arbitraria.

## Contratto R3b prima del codice

- GET merchants/activate mostra form solo alla PG base attiva coerente;
  POST con CSRF attiva il merchant del solo account corrente, senza approval.
  PF, operatore, identita incompleta/conflittuale o inattiva negati server-side.
  Gestore gia qualificato torna alla propria azienda: ripetizione non crea2.
- Riuso form/model Merchants e campi obbligatori esistenti; nuova scenario
  activation normalizza input testuali malformati e valida email. P.IVA si
  inserisce alla creazione e rimane immutabile nei successivi editor esistenti.
  Nessuna sincronizzazione implicita con dati fiscali MemberProfiles.
- Unico servizio locale per autoattivazione e create admin preesistente.
  Il vecchio create non resta disponibile ai merchant per creare altre aziende;
  admin puo selezionare solo PG eleggibili, mai PF o operatori. Owner del self
  flow deciso dal server; campi extra ID/ruolo/attivazione ignorati.
- Transazione READ COMMITTED propria: lock account destinatario, rilettura
  attore attivo/ruolo e policy R1, lock profilo PG, validazione e creazione
  merchant + promozione ruolo30 risolto dal catalogo (esattamente uno).
  Guardie ripetute dopo attesa; errore = rollback di entrambe le scritture.
  Tutti i writer applicativi merchants rilevati passano dal servizio.
- Due attivazioni dello stesso account serializzate sul lock users: un solo
  merchant, stesso ID restituito dopo verifica qualificazione. Nessun vincolo
  UNIQUE nuovo su dati legacy senza censimento; incoerenze esistenti negate.
- Nessuna chiamata BTCPay, token, grant, negozio, quota o operatore generato.
  UI chiarisce attivazione solo locale, incassi non ancora pronti. Hook/outbox
  saranno B1 su contratto separato; il successo locale non certifica pagamenti.
- Link Attiva merchant solo menu account in alto a destra; profilo non duplicato.
  Test: accessi, CSRF/metodi, extra fields, validazione/array, idempotenza,
  concorrenza a due processi, rollback e catalogo ruoli ambiguo/mancante.

## R3b verificata

Implementazione Napay: MerchantActivation condiviso tra self e create admin;
form di attivazione dal menu account, owner server-side, lock account/profilo,
transazione locale, catalogo ruolo univoco e nessuna chiamata BTCPay.
Nuovo scenario sul modello Merchants; editor successivi mantengono P.IVA
immutabile. Create legacy non piu disponibile al merchant e non promuove PF.

Master ha eseguito39 controlli HTTP/DB/service: guest/PF/operatore/inattivo e
account senza profilo negati; CSRF400/metodo405; array senza500; owner/ruolo/ID
extra ignorati; idempotenza; creazione admin solo PG; validazione email;
catalogo ruoli ambiguo/assente; CHECK temporaneo per fallimento promozione
con rollback merchant+ruolo; due processi concorrenti restituiscono stesso ID.
Bootstrap no-op dopo test dedicati. Runtime completa verde, incluso riavvio
con dati preservati e bootstrap no-op; sintassi6 file PHP/shell e diff puliti.
Nessuna suite PHPStan/Psalm configurata nel composer.json; nessuna prova
grafica browser di questo form. Nessun dato o schema sandbox modificato.

Resta R3c (portale soci/operatori/menu), oltre a B1 e prontezza incassi di
SIP-022. Il commit R3b non dichiara conclusi inviti D, provisioning o POS.

## R3c-1 - Quote riservate ai soci, contratto prima del codice

Aggiungere AccountEligibility::isMemberAccount: account attivo con identita
PF/PG coerente secondo policy R1, nessun bypass amministrativo. PG che ha
attivato merchant mantiene diritto associativo; account operatore POS non
acquista diritti socio da ruolo, login o presenza di pagamenti storici.

PayFeeController applica gate a tutte le proprie action (GET e POST), anche
callback nel browser: un operatore non avvia, conferma o aggiorna quote e
non legge storico quota. Guest resta redirect login, autenticato non socio403.
MembershipFee::quote torna non pagabile/not_member senza leggere storico
per identita non autorizzata. Webhook gia firmati restano invariati: continuano
a riconciliare pagamenti avviati in precedenza, non creano iscrizioni.

Sidebar Paga quota visibile solo con stessa policy. Nessun campo cliente puo
scegliere socio/user_id o ottenere profilo associativo. Nessuna modifica a
prezzi, durata quote, stato associativo o requisiti legali. Solo fixture test
rese esplicitamente PF/PG dove il vecchio test deduceva socio dal login;
level40 fixture chiamata operator non e operatore POS, testata come socio PF.

File master: AccountEligibility, MembershipFee, PayFeeController, sidebar,
fixture pay-fee/pay-btc/paypal-webhook e test membership-portal dedicato.
Elenco/scheda soci admin, dashboard e macroaree menu restano passi successivi:
questo micro-step non dichiara chiuso l'intero portale R3c/SIP-025.

## R3c-1 verificata - 2026-11-13

Master esegue70 controlli HTTP/DB/policy: POS dedicato, account senza profilo,
identita socio+operatore incoerente e admin senza profilo associativo negati
su tutte le route quote; PF/PG e gestore PG accedono; menu coerente, nessun
pagamento/profilo creato dai tentativi negati; disabilitazione account riletta
anche con identita gia caricata, PG incompleta negata. Guest torna al login.

Due errori di fixture/test emersi e corretti senza allargare autorizzazioni:
il link menu usa alias /quota (ora controllo entrambe le route via DOM), e
la fixture Bitcoin merchant richiedeva profilo PG esplicito. Soci delle
fixture PayPal/Bitcoin/webhook dichiarati positivamente e ripuliti solo nei
DB temporanei. Nel codice applicativo nessuna iscrizione implicita.

Runtime completa verde dopo correzioni, inclusi gateway simulati, webhook,
riavvio/DB preservato/bootstrap no-op. Sintassi PHP8.3.36 (8 file), shell e
diff verificati. Nessuna prova grafica browser, nessuna migration o modifica
dati sandbox. Restano elenco/scheda soci admin, dashboard e SIP-025 menu.

## Correzione form soci PF/PG - 2026-11-13

Decisione finale utente: ragione sociale facoltativa per PF, obbligatoria
solo PG; tipo PF/PG immutabile dopo registrazione anche per admin. Supera
precedente ipotesi di checkbox solo-admin. La registrazione pubblica mantiene
scelta PF/PG gia prevista, non si modifica qui.

Server MemberProfiles ha gia required condizionale, ma mancava whenClient:
validazione Yii nel browser la imponeva anche PF. Allineare callback JS al
tipo persistito mostrato in sola lettura, senza input is_corporate, mantenendo
required server per PG senza JavaScript. Rifiutare POST contenenti il tipo,
ed escluderlo da mass assignment e colonne salvate nell'editor. Guardia nel
modello anche su update con save(false); nessuna promozione/demozione ruolo.
Editor solo per profilo gia esistente con tipo valido, senza inventare PF
per account legacy senza profilo o convertire operatori in soci. Registrazione
e import iniziale restano i flussi che assegnano il tipo; nessuna correzione
di tipo amministrativa automatica autorizzata. Nessuna migration o backfill.

Coperto anche reimport legacy ripetibile: assegna PF/PG solo alla prima
creazione; se fonte successiva propone tipo diverso dal profilo gia presente,
import rifiutato e transazione intera rollback. Nessuna conversione silenziosa
tramite SQL dell'importatore. Test solo su database sintetici; non viene
avviato import o corretto alcun dato della sandbox condivisa.

Verifiche master: runtime completa verde con81 controlli scritture associazione,
116 signup PF/PG HTTP/DB/mail,44 bootstrap e36 import legacy sintetico;
riavvio e bootstrap no-op verdi. Cinque controlli JS del required client,
sintassi PHP8.3.36 dei6 file modificati e diff verificati. Nessuna prova grafica
browser e nessuna nuova migration, reimport o modifica dati nella sandbox.

Durante test corretti due problemi della fixture: ID cifrati vanno estratti
dalle pagine della sessione HTTP corrente, non generati nella sessione CLI;
la prova di email legacy ambigua richiede fixture temporaneamente pre-R2,
con rimozione/ripristino UNIQUE solo nel DB usa-e-getta e cleanup in finally.
I vincoli del database applicativo non sono stati allentati.
