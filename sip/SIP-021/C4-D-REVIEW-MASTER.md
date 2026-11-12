# C4 parte D - Review master inviti operatore

Data: 2026-11-12. Commit esaminati: 63911cae, f25acc04, 5a6ef31b,
19b06f0b, con 450d395d equivalente a e0132f64. Nessuna integrazione D ancora
approvata. Test dichiarati dall'agente non rieseguiti dal master in questa review.

## Correzioni richieste

1. AcceptInvitationForm limita la password a72 caratteri, non72 byte.
   Bcrypt tronca oltre72 byte: applicare controllo byte come signup/reset,
   anche al confine del servizio accept, riusando validazione esistente.
   Provare UTF8 e suffissi oltre limite senza loggare password o hash.
2. Filtri first_name/last_name mantengono array: StringValidator rifiuta,
   ma activeTextInput puo produrre500. Normalizzare input non testuali a
   stringa vuota, poi required; test HTTP per entrambi i nomi senza consumo
   invito o creazione account.
3. deliver aggiorna esito solo per ID: consegna tardiva di generazione
   precedente puo alterare esito dopo resend. CAS anche su token_sha256.
   Costruzione URL/parametri mail dentro try: errore configurazione post-commit
   deve diventare invio fallito controllato, non500 diverso per email esistenti.
   Test generazione obsoleta e fallimento costruzione/invio mail.

Correzioni assegnate all'agente nel suo worktree C4. Il master non modifica
quei file; nuova review e test prima di cherry-pick. Nessuna modifica allo
schema C1 o alle decisioni identita/SIP-023 autorizzata implicitamente.

## Verifica correzioni e finding scope/quota

Master riesegue tests/docker/pos-management.sh nel worktree C4 dopo
c9de3db0/167d84fb: 61 controlli backoffice, 50 inviti, verifica log Apache
senza token/chiavi e bootstrap no-op tutti verdi. Chiusi i tre finding
iniziali; nessuna migration o modifica dati della sandbox condivisa.

Resta da correggere: resend legge merchant/email per solo ID e chiama
throttle prima di verificare scope. Richiesta non autorizzata puo consumare
quote del tenant destinatario pur terminando404. Verificare scope corrente
prima di conteggiare, mantenendo ricontrollo transazionale sotto lock;
applicare stessa guardia al confine invite. Test: ripetuti tentativi tenant D
su risorse E non riducono quota disponibile a E. Nessun cambiamento richiesto
al componente Throttle condiviso. Fix assegnato all'agente, non applicato
implicitamente dal master. Parte D non ancora integrata nel checkout principale.

Residuo dichiarato dall'agente: configurazione URL mail non valida puo
produrre stato consegna diverso fra invito e semplice avviso (senza link).
Risposta HTTP generica resta identica; SMTP reale e resa browser non collaudati.

## Chiusura review e integrazione

f89fa28b/5b26fcaf risolvono scope/quota; master riesegue nel worktree CLA:
61 backoffice,62 inviti, log privi di token e bootstrap no-op verdi.
Importati nel master, in ordine: e6a8c9af,c536b07c,384e380d,cf1643c9,
047588fe,552d9de5,e293c5be,e5f5d86e. Conflitto nel solo runner risolto
mantenendo sia nuovi test inviti sia controlli log. Nessuna sostituzione dei
test congiunti master con copie delle gare CLA.

Nel checkout integrato:56 backoffice e62 inviti,59 test congiunti C4/API,
runtime completa con riavvio/DB preservato/bootstrap no-op verdi. Un primo
run integrato ha fallito per permessi sorgenti600 ereditati dalla umask del
backup, non per le logiche D. Ripristinati0644 su tutti i file di questa
integrazione e0755 sulla nuova cartella view, senza modificare segreti;
run confermato con RUNNER_EXIT=0. Log Apache senza token/chiavi.

Sandbox locale: prima dell'upgrade era ancora pendente R2. Preflight in sola
lettura: email vuote0 e gruppi duplicati0. Backup SQL privato0600 fuori repo,
gzip verificato (nessuna prova di restore dichiarata). Applicate R2 e D
tramite V2Bootstrap::run, senza LegacyImporter o reimport; readiness OK.
Route HTTPS / e /pos-management/index302, invito invalido200;7 controlli
trasporto BTCPay reali ancora verdi. Nessun invito/utente creato per test nel
DB condiviso. SMTP reale e verifica grafica browser restano non eseguiti.
