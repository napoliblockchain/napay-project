# Handoff master per agente Napay - profili e C4, 2026-11-12

## Base e aggiornamenti da ricevere

Worktree assegnato: `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`,
branch `feature/v2-napay-backoffice-c4`. Non lavorare nel bind mount principale.

Nuova dipendenza read-only pronta nel repo Napay:
- `5c1fd920`: `components/identity/AccountEligibility.php`.
- `00afe16a`: test e runner `tests/docker/account-eligibility.sh`.

Il master autorizza il cherry-pick di questi due soli commit **sul tuo branch
C4**, previo controllo worktree pulito. Nessun cherry-pick/merge sul branch di
integrazione. Se ci sono tue modifiche, preservale e prepara prima un piccolo
commit dei tuoi file; niente stash/reset automatici o checkout su file altrui.

Leggi SIP-023, R1-POLICY-CONDIVISA.md e SIP-021/C4-APPROVAZIONE.md aggiornati.
Non usare le vecchie ipotesi di gestore multi-merchant o registrazione pubblica
come passaggio obbligatorio dell'invito.

## Regole definitive

- Socio PF: associazione, mai merchant per quel profilo.
- PG: prima iscrizione socio PG; poi puo autoattivare merchant senza admin.
  Lo stesso account e unico gestore di un solo merchant; resta socio PG.
- Gestore non usa POS; crea soltanto operatori del proprio merchant.
- Operatore: account dedicato non socio; invito email, link, password/conferma,
  nome e cognome. Se la persona e gia socio, usa altra email e altro account.
- Merchant diversi non condividono gestori/operatori. Mai merchants[0].
- Disable operatore revoca sessioni esistenti; riabilitare richiede nuovo login.

## Dipendenza comune: usarla, non duplicarla

`AccountEligibility` espone `kind`, `isOperatorAccount`, `merchantForManager`,
`qualifiedMerchant`, `canActivateMerchant`. Contratto dettagliato in R1.

Per scope merchant, userId proviene dall'identita autenticata, non da POST:
`AccountEligibility::merchantForManager((int) Yii::$app->user->id)`.
Null = nessuno scope; non ripiegare su un array di merchant o sul primo record.
Admin richiede comunque autorizzazione esplicita e scope del record; la policy
non conferisce ruoli admin ne sostituisce CSRF/transazioni/lock.

`isOperatorAccount` verifica identita/attivita, non flag profilo o grant: questi
restano controlli C1 separati. `qualifiedMerchant` verifica la relazione PG, non
lo stato attivo dell'attore; il chiamante deve verificarlo. `canActivateMerchant`
e solo precontrollo: non crea nulla e non protegge da solo la concorrenza.

Fixture C4: creare davvero profili PG con ragione sociale e gestore di livello
merchant, non basta il merchant sintetico gia presente nel setup comune.
Account o profili incoerenti devono restare negati; non modificarli/cancellare
quote o soci per far passare un test o abilitare un operatore.

## Lavoro che puoi avanzare subito

1. Aggiorna C4-BACKOFFICE.md e C4-HANDOFF.md alle decisioni definitive.
2. Implementa e testa terminali, scope, viste/form e azioni C4 gia autorizzate
   nei file riservati; usa la policy comune per i gate identita/merchant.
3. Per scritture rileggete sotto lock dati da cui derivano scope e titolarita;
   non usare una pre-verifica UI come autorizzazione definitiva del POST.
4. Proponi contratto/schema inviti corretto: nuovo account operativo creato
   all'accettazione, non iscrizione socio o login di un account socio esistente.
   Risolvi consenso, token monouso, expiry, reinvio/errori mail e collisioni email.

Timestamp `m261112_140000_create_pos_operator_invitations.php` riservato, ma
migration e codice inviti attendono review del contratto corretto. Niente edit
alle tabelle C1. Non rinviare tutto il lavoro C4 per questo gate: avanzano le
parti indipendenti gia autorizzate.

## Cosa rimane al master

Registrazione PF/PG, attivazione merchant, scopo account/normalizzazione e
serializzazione email condivisi, filtri soci/quote e integrazione API POS.
L'helper non implica che questi flussi siano gia corretti o integrati.
Nessun edit tuo a SignupForm/Users, API, modelli C1, helper AccountEligibility,
menu/layout, routing o runner comuni. Consegnare patch richieste nell'handoff.

## Test e comunicazione

Eseguiti dal master 24 controlli R1 su DB MySQL usa-e-getta, bootstrap idempotente,
sintassi PHP/shell e review indipendente. Non sono test del flusso inviti o
self-activation completo. Replica nel tuo ambiente isolato, mai nella sandbox.
Se manca vendor, usa lock/toolchain esistenti nel tuo worktree, senza symlink ai
vendor/runtime principali o aggiornamenti PHP/dipendenze; segnala eventuali
permessi mancanti. Segreti sempre esterni e nessuno nei log.

Piccoli commit C4, poi aggiorna soltanto i tuoi C4-HANDOFF/C4-BACKOFFICE con hash,
file/test eseguiti e blocchi puntuali. Il master integra dopo review. Non
modificare i documenti master o dichiarare messaggi inviati ad altre chat se
non esiste un canale effettivo; gli handoff sono il registro condiviso.
