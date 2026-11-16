# SIP-022 - Provisioning automatico merchant, negozi e POS su BTCPay Server

- Stato: OPEN - requisiti e ownership confermati, disegno tecnico da approvare.
- Area: Napay / BTCPay / Provisioning / Sicurezza.
- Repo: `napay`, `pos`; orchestratore per documentazione/integrazione.
- Branch target: `feature/v2-yii2-php83-docker`; ownership file da riservare.
- Segnalato: 2026-11-12.
- Dipendenze: SIP-008, SIP-009, SIP-020, SIP-021.
- Gate: prima contratto/versione/permessi e decisioni aperte, poi piccoli step.

## Contesto

Requisito dell'utente: nuovo merchant Napay associato automaticamente a un nuovo
utente BTCPay; nuovo negozio associato a uno store BTCPay; nuovo POS associato
all'app POS dello store corretto. L'operatore POS continua ad accedere tramite
Napay: utente BTCPay del merchant e operatore di cassa sono entita distinte.

Il simbolo merchant <-> utente indica qui la corrispondenza da persistere.
Napay e l'unico master: creazioni o modifiche anagrafiche fatte direttamente
in BTCPay non creano o aggiornano automaticamente entita Napay. Nessuna
autorita inversa su utenti, ruoli, merchant, grant o wallet Napay. Lettura di
stati remoti, riconciliazione e notifiche di pagamento non sono import anagrafico.

## Decisioni confermate dall'utente (2026-11-12)

- Password tecnica BTCPay conservata cifrata anche dopo onboarding, solo al
  worker: rotazione gestita da Napay, recupero amministrativo per eccezioni.
  Merchant mai obbligato ad accedere a BTCPay. Dettagli e gate:
  [decisione opzione B](SIP-022/B1-DECISIONE-ROTAZIONE.md).
- Modello credenziali definitivo **P3**, dopo test B0: provisioner limitato
  e chiave cifrata/revocabile per merchant. Sostituisce P1 delle prime
  proposte. Contratto e gate: [decisione P3](SIP-022/B0-DECISIONE-P3.md).
- [SIP-023](SIP-023-profili-soci-merchant-operatori.md): merchant solo PG socia;
  gestore e operatore distinti, invito operatore non iscrive all'associazione.
  Identita BTCPay per merchant non coincide con account socio o operatore.
- La PG si iscrive come socio e autoattiva poi il proprio merchant senza
  approvazione admin. Provisioning dalla creazione/attivazione del merchant,
  non dalla sola iscrizione PG; BTCPay offline non annulla l'iscrizione
  associativa e non autorizza a dichiarare pronti gli incassi.
- Napay unico punto di gestione per merchant, negozi e POS; provisioning verso
  BTCPay, senza sincronizzazione anagrafica inversa.
- Il merchant usa soltanto Napay: BTCPay trasparente, niente inviti o credenziali
  BTCPay consegnati al merchant e nessun login BTCPay richiesto dal flusso.
- Un utente BTCPay distinto per ogni merchant. Precisazione SIP-023: ogni
  merchant ha il proprio unico account gestore, non condiviso con altri merchant.
  Non raggruppare identita remote per persona fisica, proprietario o email.
- Restano da definire identita tecnica/email per merchant e credenziali server;
  le scelte funzionali non approvano automaticamente policy, schema o API key.

SIP-021 C1 e stato ripreso e chiuso dal master il 2026-11-12 su autorizzazione
dell'utente; questo documento non autorizza altre migration o bootstrap.
Questo SIP aggiunge un flusso remoto, non sostituisce appartenenze, grant o lock
POS e non modifica le migration C1 gia condivise.

## Verifica repository

- `MerchantsController::actionCreate()` salva azienda e ruolo locale; nessun
  provisioning utente BTCPay rilevato in quel flusso.
- `StoresController` contiene un precedente flusso sincrono `createStore()` e
  persiste `storesettings.bps_storeid`. Non e un worker riconciliabile/idempotente;
  usa anche impostazioni BTCPay pregresse da revisionare, non da riattivare alla cieca.
- `components/btcpayserver/Client/Pos.php` implementa create/update/remove app
  POS Greenfield; il modello locale `Pos` richiamato dal vecchio controller
  non risulta presente nella v2. Riutilizzo solo dopo verifica compatibilita.
- Libreria ufficiale gia dichiarata: `btcpayserver/btcpayserver-greenfield-php`.
  Non aggiungere un secondo SDK o aggiornare dipendenze senza necessita.
- Il nuovo pagamento quota associativa usa `components/payments/BTCPay.php`
  e uno store configurato per l'associazione. Quel destinatario non deve
  diventare lo store condiviso di tutti i merchant.
- Lo schema attuale permette piu record merchant per utente (`Users::getMerchants()`).
  La nuova decisione SIP-023 richiede invece un account gestore dedicato per
  merchant. Censire incompatibilita legacy prima dei vincoli, senza riattivare
  gestione multi-merchant per account. Identita BTCPay ancora da definire.

## API esterne verificate e limite della verifica

Riferimento pubblico ufficiale [Greenfield v1](https://docs.btcpayserver.org/API/Greenfield/v1/):

| Risorsa | Operazione |
| --- | --- |
| Utente merchant | `POST /api/v1/users` |
| Credenziale di un utente | `POST /api/v1/users/{idOrEmail}/api-keys` |
| Store | `POST /api/v1/stores` |
| Associazione utente-store | `POST /api/v1/stores/{storeId}/users` |
| App POS | `POST /api/v1/stores/{storeId}/apps/pos` |
| Riconciliazione | GET utenti/store/app, da dettagliare sulla versione target. |

Le API key sono limitate anche dai diritti del titolare. L'aggiunta diretta a
uno store, senza invito, richiede permessi server aggiuntivi. Non basta assumere
che una chiave globale crei store di proprieta del merchant.
Fonte: [autenticazione Greenfield](https://docs.btcpayserver.org/Developers/api/).

Prima del codice acquisire versione e OpenAPI dell'istanza target (`/docs`,
`/swagger/v1/swagger.json`), senza chiavi nei dump. Verificare permessi, policy
registrazioni, approvazione utenti, quote store e plugin. La documentazione
pubblica non certifica la versione installata. Nessuna chiamata di creazione
eseguita durante questa analisi.

## Proposta funzionale

1. Napay registra l'entita e, nella stessa transazione locale, un evento di
   provisioning. Un worker dedicato elabora automaticamente gli eventi.
2. Ordine delle dipendenze: utente merchant -> store del negozio -> app POS.
   Un POS non viene creato nello store dell'associazione o di un altro merchant.
3. Persistenza dei mapping per istanza BTCPay: merchant/user ID, negozio/store ID,
   terminale/app ID. Non usare SIN, email o nome come credenziale/ID stabile locale.
   La corrispondenza merchant/utente remoto e uno-a-uno per istanza: impedire
   che due merchant condividano lo stesso utente BTCPay. Unicita dell'account
   gestore locale secondo SIP-023; la piattaforma mantiene molti merchant separati.
4. Proposta: store creato nel contesto dell'utente merchant con credenziale
   server-to-server adatta, oppure creato dal provisioner e associato esplicitamente
   al merchant secondo ruoli approvati. Scegliere un solo percorso prima del codice
   e verificarne proprieta e privilegi effettivi con due merchant distinti.
5. Stati separati dal dominio POS: `pending`, `running`, `synced`, `retry_wait`,
   `reconcile_required`, `failed`. Sono una proposta, non colonne C1 gia approvate.
   `synced` significa risorsa remota associata, non wallet configurato o incassi abilitati.
6. Creazione locale non deve dichiarare il remoto pronto quando BTCPay e offline.
   UI espone stato/errore generico e retry; niente chiamate esterne lente dentro
   transazioni DB o durante il commit del salvataggio anagrafico.

Un futuro endpoint Napay di creazione merchant/negozio/POS deve riusare questi
comandi applicativi, non creare un secondo percorso di provisioning. Non sono
qui approvati nuovi URL pubblici, payload CRUD o permessi per operatori base.

## Retry, concorrenza e riconciliazione

- Outbox locale transazionale, chiave evento univoca e unicita mapping per
  istanza/tipo/entita. Un solo job attivo per risorsa, con lease e controllo versione.
- Dopo ogni successo remoto salvare subito ID e checkpoint prima di procedere
  al passo successivo. Riavvio worker riprende dal checkpoint, senza ricreare
  risorse gia mappate. Testare due worker simultanei e riavvio tra i passaggi.
- Timeout dopo POST puo significare creazione remota gia avvenuta: non esiste
  transazione distribuita e non si presume supporto a `Idempotency-Key`.
  Prima riconciliare; se non e possibile identificare univocamente la risorsa,
  fermare in `reconcile_required`, non ripetere ciecamente il POST.
- Nomi uguali o email esistente non autorizzano ad agganciare account/store
  altrui. Mapping preesistente verificato o procedura di riconciliazione autorizzata.
- Retry automatici con backoff limitato per errori transitori e 429, rispettando
  Retry-After quando previsto. Errori permanenti/permessi mancanti non generano
  cicli infiniti o elevazioni automatiche dei privilegi.
- Niente DELETE compensativi automatici: utenti/store/app possono gia avere
  operazioni o dati remoti. Archiviazione, disabilitazione e trasferimenti
  richiedono regole dedicate prima dell'implementazione.

## Sicurezza e confini

- Provisioner con credenziale separata da fatturazione/checkout e dagli operatori
  POS. Segreti esterni ai repo, montati come file o gestiti da secret manager;
  rotazione e accesso del worker limitati. Mai admin key nel browser/POS client.
- Minimo privilegio verificato sull'istanza. Alcune operazioni amministrative
  richiedono privilegi elevati: approvarli e limitarli al processo di provisioning,
  non copiare `unrestricted` nel normale client pagamenti per far passare i test.
- Nessuna password Napay copiata a BTCPay; password/hash non replicati. Utenti
  remoti usati dal backend, senza inviti automatici o credenziali al merchant.
  Prima del codice verificare sulla versione target come creare l'identita
  tecnica senza email di attivazione indesiderate e senza bloccare le API.
  Non assumere che disabilitare l'account per impedirne il login lasci valide
  le API key, ne aggirare policy di conferma/approvazione del server.
- API key per merchant, se necessaria, resta solo server-side con storage protetto
  e ciclo di revoca definito; proposta di storage, non secret da mettere in chiaro
  nelle tabelle mapping. Niente credenziali nei log, outbox, errori UI o audit.
- Origine BTCPay configurata e allowlist, TLS CA/hostname verificati, redirect
  disabilitati, timeout e limiti risposte. Riutilizzare il percorso egress sicuro
  del backend; nessuna nuova uscita Internet dal container POS.
- Destinatario BTC del merchant da configurare/verificare separatamente: nessun
  seed, chiave privata o wallet dell'associazione assegnato automaticamente.
  Wallet TTS del merchant resta distinto; questo SIP non ne decide la custodia.
- Creazione/riconciliazione autorizzata nel backend, scope merchant/store/POS
  verificato server-side; il solo ID remoto non dimostra titolarita.

## Micro-step e ownership proposta

1. B0: autorita sync, cardinalita e accesso merchant confermati sopra; definire
   identita tecnica per merchant e verificare versione/API/permessi/policy
   in ambiente BTCPay di test senza denaro reale.
2. B1: mapping/outbox/worker e test, nuovi file dedicati e migration riservata
   dopo coordinamento del master. Nessuna modifica autonoma al codice C1.
3. B2: creazione/associazione utente merchant, collisioni e riconciliazione.
4. B3: creazione store e verifica ownership con almeno due merchant di test.
5. B4: creazione app POS sullo store mappato e checkpoint idempotenti locali.
6. B5: stato visibile nel backoffice, retry autorizzati e documentazione operativa;
   test integrazione reale prima di dichiarare il provisioning disponibile.

File condivisi da concordare: MerchantsController, StoresController, futuro
CRUD terminali, gestione segreti/egress, runner test e ordine migration.
Implementazioni nuove nel dominio provisioning; non duplicare autenticazione,
trasporto sicuro o SDK gia esistenti. Nessuna implementazione implicita da questo SIP.

## Criteri di accettazione

- Nuove risorse locali generano automaticamente le tre risorse remote corrette.
- Secondo negozio/POS non ricrea l'utente merchant; merchant diversi non
  condividono risorse per errore. Mapping ripetuto non crea duplicati locali.
- Due merchant distinti hanno account gestore locali e utenti BTCPay distinti.
  Nessun invito/login remoto richiesto al merchant; nessuna password Napay
  trasmessa. Risorse create direttamente su BTCPay non popolano anagrafiche Napay.
- Account/store preesistenti e timeout ambigui non producono agganci cross-tenant
  o duplicazioni cieche. Recovery dopo crash verificato con backend reale di test.
- BTCPay indisponibile lascia stato locale onesto e retry persistente.
- Permessi e ownership verificati, segreti assenti da browser/log/audit.
- Login POS resta Napay, nessun SIN da conoscere e nessun lock simulato.
- Mock dimostrano solo gestione errori; collaudo remoto di test necessario per
  provisioning/ownership effettivi. Nessun pagamento reale o cancellazione remota.

## Dettagli tecnici ancora aperti

- Identita tecnica/email distinta e stabile per ogni merchant, dominio/recapiti
  gestiti e politica di recupero; non derivarla automaticamente dall'email del
  titolare come scorciatoia per accorpare merchant diversi. Nessun indirizzo fittizio inventato
  nel codice prima di questa decisione.
- Modalita di creazione degli account senza inviti, policy di conferma/approvazione
  e credenziali backend compatibili con l'istanza target, senza accesso UI richiesto
  al merchant. Protezione/rotazione dei segreti e percorso di ownership dello store.
- Politica utenti gia esistenti, cambi email, disabilitazioni, archiviazioni,
  cancellazioni e ruolo amministrativo del provisioner da approvare in B0.

## Stato B0, review integrazione 2026-11-12

Importati solo esiti/handoff documentali (`2306fe9`), non stack o patch condivise.
[Review integrazione](SIP-022/B0-REVIEW-INTEGRAZIONE.md) sospende integrazione e
fase 2 per protezioni filesystem, validazione reti e isolamento dal proxy egress.
Due reti distinte backend/client sostituiscono la proposta edge condivisa con
Squid. Correzioni all'agente nel branch B0; nessun provisioning B1 autorizzato.

## Decisione xpub (utente, 2026-11-16)

Soluzione A: ogni merchant fornisce la xpub del proprio wallet BTC; Napay la
valida e la imposta sullo store del negozio, senza mostrarla (schema di
derivazione e key path nascosti, SIP-030 punto 4). Napay non custodisce seed o
chiavi private e non genera wallet per i merchant.

## Collaudo reale B2-B4 (2026-11-16)

`napay/tests/docker/btcpay-provisioning-e2e.sh`: worker Napay vero contro
BTCPay 2.4.7 regtest usa-e-getta, attraverso gateway TLS `btcpay.local` (CA
locale) e proxy di uscita Napay; DB con i ruoli reali (worker ristretto).
**8 PASS**: due merchant con utente BTCPay tecnico e chiave verificata
ciascuno, store e app POS creati, ogni store ha come membro solo il suo
merchant, chiave del merchant B rifiutata (403) sullo store di A, seconda
esecuzione di run/links/reconcile senza lavoro né nuove risorse. Log senza
segreti, pulizia completa a fine test (anche in caso di errore).

Scoperta: un utente admin di BTCPay **non** legge le app degli store di cui
non è membro (403, manca `canmodifystoresettings`). Quindi la chiave ponte
`BTCPAY_STORES_API_KEY` (SIP-030) funziona solo sugli store di cui il suo
utente è membro (negozi v1); per i negozi creati dal provisioning le modifiche
devono passare dal worker con la chiave del merchant (passo 3).

## Permessi delle chiavi

| Chiave | Dove | Permessi |
| --- | --- | --- |
| Provisioner | solo worker (file segreto) | `btcpay.server.cancreateuser`, `btcpay.server.canviewusers` (verificati) |
| Merchant | creata da Napay per ogni merchant, cifrata | `btcpay.store.canmodifystoresettings` (verificato: store e app POS); xpub e webhook da verificare nei passi successivi |
| Quote associative (`BTCPAY_API_KEY`) | env web | `btcpay.store.cancreateinvoice`, `btcpay.store.canviewinvoices`, solo sullo store dell'associazione |
| Ponte negozi (`BTCPAY_STORES_API_KEY`) | env web | `btcpay.store.canmodifystoresettings`, utente membro degli store v1 |

Mai: `unrestricted`, `btcpay.server.canmodifyserversettings`,
`btcpay.impersonation.canimpersonate`, `btcpay.server.canmanageusers`
(solo nel test, per le chiavi di verifica), permessi di firma o invio
transazioni (Napay non detiene chiavi private).

## B5 - Worker e stato nel backoffice (2026-11-16, napay `6bf5b0a8`, `fca79e2d`)

- Servizio `btcpay-worker` (overlay `docker-compose.btcpay-worker.yml`, dopo
  quello dei ruoli): nessun daemon PHP, `docker/btcpay-worker-loop.sh` esegue a
  intervalli (`BTCPAY_WORKER_INTERVAL`, default 30 s) i tre comandi one-shot
  `run`, `links`, `reconcile`, massimo 25 lavori per comando a passata. Utente
  DB `worker`, segreti provisioner e portachiavi solo a lui, uscita solo dal
  proxy. Il web riceve solo `BTCPAY_PROVISION_INSTANCE` (digest pubblico).
- Sandbox: `docker/local.sh` include il worker solo se esiste
  `btcpay-provisioner-key` nella cartella privata; crea una volta il
  portachiavi `btcpay-kek-keyring`; origine `https://btcpay.local` con la CA
  del gateway. Controllo di isolamento esteso (reti, segreti, ruolo, origine).
- Stato nel backoffice, letto con i permessi del web: dettaglio merchant
  (account BTCPay), dettaglio negozio (pagamenti BTC), elenco terminali.
  Quattro stati: collegato, in corso, verifica in corso, errore (contatta
  l'amministrazione). Nessun codice tecnico mostrato.
- Test: ciclo del worker con CLI finto (5), coda con web ristretto (47),
  collaudo reale con stato "collegato" (8), isolamento sandbox (43).

### Riprova dell'admin, R1 store e POS (2026-11-16, napay `1ac283a4`)

Decisione utente: riprova sicuro, senza doppioni. Il web (solo admin, POST con
CSRF) accoda un nuovo lavoro con la generazione successiva, solo se l'ultimo
è `failed`, `deferred` o `reconcile_required`; mai modifiche ai lavori. Nel
worker, per una generazione > 1:

1. mapping `failed`/`suspended` senza ID remoto: torna in riconciliazione;
2. GET della lista (store del merchant o app dello store): marker unico
   trovato = adottato, nessuna nuova risorsa;
3. marker assente in una lista completa (200): se un POST della risorsa era
   in volo da meno di 15 minuti (`ADMIN_RETRY_QUIET`) si attende; dopo, i
   lavori precedenti sono chiusi (`superseded`) e il mapping torna `pending`,
   così il passo successivo fa un solo POST con checkpoint;
4. marker multiplo, 401/403, lettura non disponibile: come prima (admin).

Cambia la regola B1 "nuova generazione dopo POST incerto: solo GET per
sempre": ora, trascorsa la quiete, una lista completa a vuoto consente di
ricreare. Test: link worker (62, casi nuovi), collaudo reale (12: adozione,
ricreazione, attesa di quiete, riprova rifiutato se il collegamento è a posto),
accesso solo admin (negozi 32).

### Riprova dell'admin, R2 account merchant (2026-11-16, napay `c05ee10d`)

Account `reconcile_required`/`failed`/`suspended` con generazione > 1 (merchant
ancora idoneo, ricontrollato dal web e dal worker):

- utente remoto già noto: nuova chiave (passo B, generazione successiva) e
  verifica (C); utente invariato;
- utente non confermato: A-r, `GET /api/v1/users/{email tecnica}` con la
  chiave del provisioner. Assente: passo A con la stessa password salvata
  (BTCPay rifiuta email doppie). Presente: adottato solo se la password salvata
  crea la chiave (B), prova di proprietà; 401 = riconciliazione, nessuna
  chiave utilizzabile. Mai reset o modifica di un utente esistente;
- generazioni finite (3): nessuna chiamata, resta all'admin.

Pulsante sul dettaglio merchant (solo admin). Test: worker account (44, 5
nuovi), collaudo reale (13: stesso utente ritrovato per email, chiave di
generazione 2).

### Passo 3 - Impostazioni dei negozi tramite il worker (2026-11-17, napay `a8ad1da2`)

- Nuovo lavoro `store_update` (migration `m261117`): nome, valuta e impostazioni
  fisse dello store BTCPay, applicati dal worker con la chiave del merchant
  (`PUT /api/v1/stores/{id}`, idempotente: un esito ignoto si ripete). Valori
  letti da Napay all'esecuzione; stesso lock dello `store_link`; dipendenze
  account e store collegati. Accodato alla creazione del negozio e a ogni
  modifica di nome o valuta, nella stessa transazione. Il web non chiama
  BTCPay per i negozi del provisioning; la chiave ponte resta per i v1.
- Il worker legge nome del negozio e colonne del payload (permessi di
  colonna), non recapiti, ID store v1 o dati di derivazione.
- Scoperte sul BTCPay reale: il nome di uno store ha al massimo **50
  caratteri** (422 su `name`), quindi il nome di creazione con marker resta
  entro 50; a collegamento fatto `store_update` mette il nome pulito del
  negozio (visibile al cliente nel checkout), perché l'ID remoto è già
  salvato e il marker serve solo finché la creazione è incerta. Le colonne
  JSON salvate da ActiveRecord sono codificate due volte: il payload le legge
  in entrambe le forme. Un 422 riporta ora il campo rifiutato nel codice
  (es. `store_update_rejected_name`).
- Test: link worker 69 (6 nuovi), collaudo reale 15 (impostazioni applicate,
  modifica di nome e valuta, adozione su uno store appena creato), permessi
  DB 65, schema 148, runtime.
- Resta (3b): archiviazione su BTCPay dei negozi del provisioning eliminati e
  rimozione delle app POS dei terminali disattivati, tramite worker. Il cambio
  BTC nella pagina negozio resta solo per i negozi v1.

### Webhook per store (passo 4, da fare)

In BTCPay i webhook sono per store: li crea il worker per ogni store
collegato, con un segreto diverso per store (cifrato come le chiavi), verso
l'endpoint Napay; serve anche il permesso
`btcpay.store.webhooks.canmodifywebhooks` (da verificare se incluso in
`canmodifystoresettings` sul regtest).
