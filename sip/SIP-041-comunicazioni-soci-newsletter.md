# SIP-041 - Comunicazioni ai soci e newsletter

- Stato: OPEN (perimetro newsletter confermato dall'utente il 2026-11-26;
  contratto tecnico proposto, nessun invio o codice implementato).
- Area: Associazione / Email / Preferenze.
- Repo: napay; orchestratore per documentazione.
- Branch documentale: feature/member-communications, da origin/main.
- Dipendenze: SIP-020/023/030 (soci e ruoli), SIP-039/040 (privacy e consensi).
  Le schede 037-040 non sono ancora tutte integrate nel main verificato;
  dipendenze da riconciliare, non considerate automaticamente implementate.

## Contesto

Legacy: protected/controllers/MailingController.php, MailingForm, viste mailing
ed email mailings.php. Modulo pensato per eventi (oggetto, data, ora, luogo,
testo), destinatari ricavati da tutti gli Users, invii Ajax dal browser,
nessuna coda persistente o filtro specifico soci/consensi nel modulo esaminato.
L'endpoint dichiara accesso agli autenticati e restituisce successo senza
valutare il risultato del mailer. Non portare quel codice Yii1.

In v2 esistono sendMail::toUser, SMTP/file transport, template con brand attuale,
MembershipReminders e container cron. Non esiste una campagna persistente.

## Proposta

### Categorie e destinatari

- Comunicazione associativa: convocazioni, avvisi istituzionali o di servizio.
  Destinatari soci ammessi dalla finalita scelta, non tutti gli utenti Napay.
- Newsletter: comunicazioni promozionali, consentite solo con consenso marketing
  positivo e attuale. Assenza/valore incerto/revoca escludono il destinatario.
- La categoria non e un espediente per bypassare preferenze: finalita e testi
  approvati dall'associazione e coordinati con SIP-039/040, senza conclusioni
  legali implicite dal software.
- Operatori POS non soci esclusi. Il merchant puo ricevere in qualita di socio
  PG. Filtri PF/PG, quota e selezione manuale espliciti, con conteggio anteprima.
- Consenso marketing separato da privacy/condizioni e da reminders_opt_out:
  accettare nuove condizioni o promemoria quote non iscrive alla newsletter.
- Verificare origine/timestamp dei consensi importati; niente ricostruzione o
  consenso inventato. Casi incerti esclusi fino a verifica o nuovo opt-in.
- Ricontrollare eleggibilita, email corrente, consenso e soppressioni immediatamente
  prima del tentativo d'invio. Uno snapshot di campagna non autorizza invio dopo revoca.

### Interfaccia e permessi

Voce Associazione -> Comunicazioni, inizialmente solo admin; eventuale segretario
richiede decisione esplicita. Bozza con categoria, oggetto e corpo; dati evento
facoltativi, non obbligatori per ogni messaggio. Anteprima, invio di prova,
conteggio e conferma esplicita prima di accodare. Template HTML e testo,
brand attuale, nessuna risorsa di tracciamento o font remoto aggiunto.
Niente HTML arbitrario: riusare renderer/sanitizzazione mantenuti esistenti.

### Preferenze e disiscrizione

Profilo con preferenza newsletter distinta; revoca semplice senza login dal
messaggio mediante link dedicato limitato alla disiscrizione, non valido per login.
GET mostra conferma senza mutare stato (protezione da scanner dei link); POST
idempotente revoca con verifica del token e protezioni appropriate al flusso.
Token non in log o analytics. Meccanismo client one-click eventualmente separato
va specificato e testato prima di abilitarlo.

Revoca registrata come evento di preferenza e applicata anche alla coda. Un nuovo
opt-in richiede azione esplicita dell'interessato: mai riattivazione tramite admin,
import, invito operatore o accettazione delle condizioni. Policy account/email
riutilizzata e prova dell'opt-in da fissare nel contratto prima delle migration.

### Coda, affidabilita e trasporto

Proposta minima: tabelle campagne e destinatari, stato e audit degli invii.
Unicita campagna/account e deduplicazione indirizzi normalizzati; nessun elenco
email in To/Cc condiviso, un messaggio per destinatario. Snapshot contenuto reso
immutabile alla conferma, filtri e conteggi registrati senza PII nei log generici.

Worker CLI a piccoli lotti, avviato dal cron gia esistente: niente coda Redis o
secondo mailer necessario. Claim concorrenti/lease, pausa/annullamento, limite
configurabile che non saturi SMTP a scapito di password reset e attivazioni.
Nessun invio nel ciclo HTTP o dal browser. Eventuale ripresa dopo crash verificata.

Riutilizzare mailer Yii2 tramite wrapper esistente o estensione minima compatibile.
SMTP accettata non significa consegna in casella. Tracciare queued/processing/
accepted/failed/unknown/skipped. Non promettere exactly-once: timeout dopo accettazione
SMTP puo lasciare esito incerto, da riconciliare senza retry cieco.
Bounce/reclami/consegna richiedono canale provider autenticato dedicato; non simulare
uno stato delivered con il solo send()=true. Non introdurre dipendenza API provider
nel primo passo. Quote effettive e autenticazione dominio verificate prima di invii reali.

## Criteri di accettazione

- Anonimo, socio, merchant e operatore non possono gestire campagne o destinatari.
- Mutazioni POST con CSRF; input limitati e validati, output codificato/sanitizzato.
- Newsletter esclusa senza consenso; operatori esclusi e filtri PF/PG coerenti.
- Revoca prima del claim impedisce invio; revoca durante batch rispettata ai
  controlli successivi. Invio gia accettato da SMTP non puo essere richiamato.
- GET disiscrizione non muta; POST e token invalidi/scaduti/riusati gestiti senza
  accesso all'account, enumerazione o riattivazione accidentale.
- Coda concorrente, doppia conferma, crash, quota SMTP e timeout incerto collaudati.
- Chiusura browser non interrompe campagna. Nessuna email esposta ad altri destinatari.
- Test esclusivamente file transport/SMTP fixture e DB usa-e-getta, mai soci reali.
- Nessuna nuova campagna automatica dopo migration/import o riavvio container.

## Impatto

Napay: controller/form/service/template, preferenze profilo, migration additive,
cron dedicato con flag inizialmente spento, ruoli DB minimi e test. Nessuna
modifica POS/wallet necessaria nel primo perimetro. Retention campagne, contenuti,
destinatari e token coerente con policy approvata in SIP-039, non inventata qui.

## Note implementative

Micro-step: contratto categorie/consensi -> schema e campagne in bozza -> anteprima
file/test -> worker e revoca -> collaudo isolato -> attivazione autorizzata.
Prima del codice concordare audit dell'opt-in, preferenze, tempi token, ruoli,
filtri e policy degli esiti incerti. Nessuna migration o invio autorizzati dalla
sola approvazione del perimetro newsletter.

## Verifica repository

Analisi statica svolta su legacy napay-1 e v2 napay, 2026-11-26. Nessun codice
applicativo modificato, nessun test funzionale eseguito o messaggio inviato.
