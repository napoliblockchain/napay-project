# SIP-023 - Separazione soci PF/PG, gestori merchant e operatori POS

- Stato: OPEN - requisiti confermati, schema e adeguamenti applicativi da progettare.
- Decisioni funzionali: CONFERMATE dall'utente il 2026-11-12.
- Area: Identita / Associazione / Merchant / Autorizzazioni.
- Repo: `napay`, `pos`; orchestratore per contratti e coordinamento.
- Segnalato: 2026-11-12.
- Dipendenze: SIP-020 (associazione), SIP-021 (operatori/POS), SIP-022 (BTCPay).
- Gate: questo documento registra le decisioni utente; non autorizza migration,
  conversioni dei dati, assegnazioni di privilegi o modifiche del codice esistente.

## Contesto

Napay gestisce sia iscrizioni associative sia attivita dei merchant. Nel
legacy ci si iscrive come socio persona fisica (PF) oppure persona giuridica
(PG). L'iscrizione associativa non conferisce operativita commerciale.
Un account e una credenziale personale di accesso: non e automaticamente un
socio, una persona giuridica, un merchant o un operatore POS.

Decisioni confermate dall'utente il 2026-11-12:
- Solo una PG socia puo scegliere di diventare anche merchant; non una PF.
- Il gestore merchant amministra ma non opera sul POS con quell'account.
- Una persona puo essere socio e operatore, ma deve utilizzare due account
  con due email differenti.

## Profili e capacita

| Profilo | Ambito | Capacita | Esclusioni |
| --- | --- | --- | --- |
| Socio PF | Associazione | Iscrizione, anagrafica, quote e funzioni associative autorizzate. | Nessun merchant e nessuna operativita POS derivano dall'iscrizione. |
| Socio PG | Associazione | Iscrizione/anagrafica/quote della persona giuridica tramite account autorizzato; scelta facoltativa di diventare merchant. | PG non implica merchant attivo; iscrizione da sola non abilita incassi. |
| Gestore merchant | Azienda/merchant | Gestione dei propri merchant, negozi, terminali e operatori secondo scope e permessi. | Non usa POS con quell'account; non acquisisce grant operatore per ruolo. |
| Operatore POS | Cassa | Account dedicato, attivo, invitato dal merchant; POS dei soli negozi esplicitamente assegnati. | Non e socio per effetto dell'invito; nessuna amministrazione merchant o dei suoi operatori. |
| Admin piattaforma | Amministrazione | Funzioni amministrative esplicitamente autorizzate. | Non diventa operatore per ruolo; non aggira grant o lock POS. |

Pagare la propria quota associativa non e operativita commerciale merchant:
la distinzione non elimina i flussi quota Bitcoin/PayPal/contanti di SIP-020.

## Regole vincolanti

1. **Societa ed account distinti.** La PG e l'entita associata; l'account
   autorizzato che la gestisce non va confuso con l'anagrafica della societa.
   La PG puo essere contemporaneamente socia e merchant, senza perdere il
   proprio stato associativo.
2. **Merchant solo PG.** Scelta disponibile nel flusso della PG socia;
   qualificazione associativa e legame alla PG verificati server-side. Nessun
   ruolo merchant autoassegnato da un flag del form PF o dall'invito operatore.
   Non e qui introdotta una nuova approvazione manuale obbligatoria: il processo
   tecnico di attivazione deve rispettare la scelta e i controlli definiti.
3. **Gestore non cassiere.** L'account che amministra il merchant non puo
   acquisire o utilizzare un POS. Per lavorare alla cassa serve un distinto
   account operatore, non un ulteriore permesso sullo stesso account gestore.
4. **Operatore non socio.** Invito e accettazione non creano record socio,
   quote, iscrizioni o ruoli associativi. Operatore legato a un solo merchant,
   assegnabile esplicitamente a piu negozi di quel merchant, come in SIP-021.
5. **Socio e operatore della stessa persona.** Consentito solo con due account
   e email differenti. Vietato riutilizzare l'account/email del socio per
   trasformarlo o collegarlo come operatore. Confronto email secondo la
   normalizzazione applicativa; spazi o differenze di maiuscole non costituiscono
   una seconda email. Nessuna regola speciale sui provider/alias introdotta qui.
6. **Invito merchant.** Merchant inserisce email per nuovo operatore. Link di
   accettazione, password/conferma, nome e cognome; altri dati solo se necessari.
   Account base operativo e appartenenza dopo consenso verificato, senza
   iscrizione associativa automatica o grant/abilitazioni impliciti.
7. **Email gia esistente.** Non sovrascrivere password, non collegare socio o
   gestore e non rivendicare account con un'email nota. Per email gia appartenente
   a un socio occorre un'altra email per l'operatore. Messaggi, recupero inviti
   e casi di account operatore gia presente richiedono contratto tecnico sicuro.
8. **Revoca.** Disabilitazione profilo operatore revoca le sessioni POS esistenti;
   riabilitazione richiede nuovo login. Disabilitazione grant/terminale e
   ricontrollata alla richiesta successiva; nessuna concessione per ruolo.
9. **BTCPay.** L'utente BTCPay e un'identita tecnica distinta per merchant PG,
   non il socio PF o l'operatore. Nessun invito/login BTCPay per il merchant;
   Napay resta master. Le email tecniche di provisioning sono questione separata
   dalle due email personali richieste per socio/operatore.

## Stato attuale e adeguamenti necessari

Ricognizione successiva del master:
[R0 - modello attuale e gate condiviso](SIP-023/R0-MODELLO-ATTUALE.md).
Include elenco/scheda/quote soci, che oggi non distinguono esplicitamente
tutti gli account operativi dalle identita associative. Correzione necessaria
anche fuori dal solo invito C4, prima di dichiarare applicato questo SIP.

Il livello tecnico base (0) esistente non rappresenta da solo uno scopo account:
un account associativo puo avere quel livello senza essere un operatore.
C1 conserva appartenenza e grant separati, C2 richiede ruolo base attivo e
profilo/grant/terminale abilitati; questo impedisce grant impliciti ma **non
certifica ancora l'intera separazione socio/operatore richiesta qui**.
Non dichiarare la regola implementata solo perche il catalogo filtra il livello 0.

Prima del codice serve un disegno esplicito di scopo account, legame socio PF/PG,
qualificazione merchant e vincoli di esclusione/normalizzazione email. Verificare
registrazione pubblica, inviti, API, UI e dati importati; non affidarsi al menu.
Non introdurre ora una nuova colonna o tabella per supposizione.

Inviti C4: l'agente Napay aggiorna il proprio allegato per recepire questo SIP;
puo proseguire sulle parti gia autorizzate indipendenti, senza toccare modelli,
registrazione o API condivise. Il master riserva eventuali nuovi cambi comuni.

## Migrazione e compatibilita

- Censire account, soci PF/PG, merchant, profili/grant e collisioni email.
  Un account importato ambiguo non riceve privilegi per inferenza automatica.
- Nessuna conversione di PF in merchant, duplicazione socio o riuso delle
  password per generare operatori. La persona interessata deve usare il flusso
  di invito con altra email; niente email fittizie o alias inventati dal sistema.
- Dati legacy discordanti richiedono piano esplicito di riconciliazione,
  preservando storico, quote e audit; non cancellare o riscrivere anagrafiche.
- L'effetto di cessazione/sospensione associativa sull'attivita merchant resta
  da definire: nessuna disabilitazione commerciale automatica introdotta qui.

## Criteri di accettazione

- Registrazione PF: solo socio; nessun merchant/operatore implicito.
- Registrazione PG: socio, con scelta merchant facoltativa e riferita alla PG.
- Merchant/gestore non opera POS, anche conoscendone ID o avendo sessione valida.
- Invito operatore non crea socio; dopo consenso crea solo account e appartenenza
  previsti, con abilitazioni/grant espliciti e limiti C1.
- Email socio o gestore non riutilizzabile per creare/collegare operatore;
  mai reset password di un account esistente tramite invito. Test concorrenti
  e con varianti email normalizzate, senza enumerazione globale al merchant.
- Stessa persona: account socio e operatore distinti, due email; dati e menu
  separati e nessuna perdita dei diritti associativi dell'account socio.
- Trasformazioni di ruolo/scopo ricontrollate dalle API, non solo dalle viste.
- Regressioni quote/iscrizioni SIP-020, grant/sessioni SIP-021 e mapping SIP-022.

## Ownership e gate

Fonte normativa trasversale: questo SIP prevale sull'uso ambiguo di "base" nei
vecchi allegati. Le decisioni gia confermate di SIP-021 restano valide, con
questa precisazione dei profili. Master mantiene SIP-020/021/022/023 e registro;
altro agente aggiorna C4-BACKOFFICE/C4-HANDOFF. Nessun nuovo accesso ai file
condivisi o applicazione migration autorizzato dal solo aggiornamento documentale.
