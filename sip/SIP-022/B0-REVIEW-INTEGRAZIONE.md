# SIP-022 B0 - Review integrazione master

Data: 2026-11-12. Esaminati `57f0f29`, `1fcd03c`, `04c721a` nel worktree
orchestratore `feature/btcpay-regtest-b0`, base `ecfa051`.

## Esito

Preparazione B0 valida come direzione, ma **integrazione e fase 2 sospese**
per i finding sotto. Gli 11 PASS dell'agente non certificano questi casi.
Il master non ha rieseguito la suite B0 attuale, non ha importato i commit,
non ha applicato patch a gateway/infra/launcher/egress e non ha avviato stack
persistente, creato utenti BTCPay o contattato produzione.

## Finding bloccanti

### B0-RV1 - P2: percorsi e file privati non confinati

`docker/btcpay-regtest/local.sh:15-35`: confronto del percorso solo lessicale,
nessuna normalizzazione di `..` o controllo antenati symlink. Percorso esterno
puo risolvere dentro repository. `exec 9>control.lock` segue link e tronca il
target prima di verificare file/lock; anche `status` puo modificare file estranei.

`local.sh:37-49`: un `regtest.env` symlink pendente supera `! -e`, viene scritto
tramite redirezione e rifiutato solo dopo. Il rifiuto arriva dopo il danno.

Richiesto: canonicalizzazione prima di controlli/modifiche; niente stato sotto
checkout applicativi, ne tramite alias/antenati symlink; validare tipo,
proprietario e permessi di file esistenti prima di aprirli. Lock non troncante;
creazione segreti atomica/no-clobber, mai sostituire input preesistente dubbio.
Verificare anche `.gitignore`. Test negativi in albero temporaneo con sentinelle:
nessun contenuto/permesso bersaglio alterato, nessun Docker necessario.

### B0-RV2 - P2: rete esterna preesistente accettata

`local.sh:60-63`: se esiste una rete omonima con Internal=false viene riusata.
Lo stack non garantisce piu assenza di uscita. Richiesto: verificare rete
internal/bridge e identita attesa, fallire senza modificarla se incompatibile.
Stessi controlli nella futura patch al launcher master, non solo nell'avvio B0.

### B0-RV3 - P2: patch proxy apre uscita indiretta dal regtest

`B0-HANDOFF.md`, patch Napay: collegare `egress` alla stessa rete edge del
container BTCPay rende Squid raggiungibile da BTCPay sulla 3128. Squid ascolta
su tutte le interfacce e accetta sorgenti private; fra gli host permessi ci
sono PayPal live e BTCPay produzione. Rete Docker internal non impedisce quel
tunnel. Nessuna chiamata reale e stata eseguita per dimostrarlo.

Correzione architetturale master prima del codice:

- `btcpay_regtest_edge`: solo gateway e BTCPay, interna;
- `btcpay_regtest_client`: solo gateway e proxy egress Napay, interna;
- alias `btcpay.local` del gateway sulla client, non connettere egress alla edge;
- Napay web resta sulle sue reti, nessun accesso diretto HTTP al backend BTCPay;
- nessuna modifica permissiva alle ACL del proxy; CONNECT solo host esatto:443.

L'agente aggiorna patch/handoff con questo disegno e test del percorso negativo;
il master integra i file condivisi solo dopo nuova review. Non provare host reali:
usare endpoint sentinella isolato per verificare assenza di tunnel in uscita.

### B0-RV4 - P3: test di isolamento non discriminanti

`tests/isolated.sh:45`: strumento assente puo equivalere a test egress passato.
Riga 48: hostname RPC non risolto o risposta HTTP 401 (per effetto di curl -f)
sono considerati isolamento, ma non dimostrano che IP/porta siano irraggiungibili.
Richiesto: prerequisiti strumenti espliciti, controlli positivi, prova TCP verso
IP effettivo RPC dalla rete edge; servizio raggiungibile con 401 deve far
fallire il test. Testare anche client/backend separati e proxy indiretto con
sentinelle locali, senza contattare produzione/Internet.

## Assegnazione correzioni

All'agente Napay, stesso branch/worktree B0 e write set originario:
`docker/btcpay-regtest/*`, `sip/SIP-022/B0-{ESITI,HANDOFF}.md`.
Nuovi test filesystem/reti ammessi sotto `docker/btcpay-regtest/tests/`.
Nessun edit diretto ai file master di gateway/infra/start-localhost o Napay.
Aggiornare patch proposte; commit piccoli, test eseguiti/non eseguiti espliciti.
Nessun riavvio condiviso, reset persistente o provisioning B1.

CA locale, trust nel futuro worker, eventuale hostname browser e policy del
server restano gate della fase 2, non aggirati disabilitando TLS. La topologia
approvata qui sostituisce la patch rete singola della prima consegna.

## Verifica indipendente filesystem

Master: quattro riproduzioni riuscite senza Docker reale, su copia del launcher
in albero temporaneo e binario docker sostituito da stub locale innocuo:

- `status` tronca una sentinella esterna tramite symlink control.lock;
- `up` scrive target di regtest.env symlink pendente prima di rifiutarlo;
- percorso con `..` viene accettato dentro la radice applicativa copiata;
- antenato symlink viene accettato dentro la stessa radice copiata.

Nessun file dei checkout, segreto persistente o servizio condiviso toccato;
albero temporaneo e segreti generati dalla sonda eliminati. Verifiche di rete
RV2/RV3/RV4 rimangono analisi del codice/configurazione, non traffico eseguito.
La prova non sostituisce i nuovi test di regressione richiesti all'agente.

## Seconda consegna - autorizzazione integrazione fase 1

Commit agente `caa4769`, `45038bd`, `83536ed`, `bf70527`, `f6be0a8`,
`bc4d756`, `eb69199` revisionati il 2026-11-12: guardie filesystem/no-clobber,
reti validate, due reti backend/client e blocco laterale gateway risolvono
RV1-RV4 nel disegno. Master riesegue filesystem27 e topology11: positivi.

Il runner isolated corretto si e fermato su confronto di nomi reti ordinati:
`sort` e atteso non usano stesso ordine fra trattino/underscore. Non e prova
di difetto d'isolamento, ne un PASS dello stack. Prima di approvare fase 1 il
master normalizza ordinamento atteso/effettivo con LC_ALL=C e riesegue tutti
14 controlli. Fix nel checkout principale, nessun edit al worktree agente.

Autorizzata integrazione selettiva di stack/test/doc consegnati e successiva
patch master gateway/infra/egress a due reti, con validazione configurazioni e
test isolati prima di riavvii locali. Nessuna produzione/reset persistente.
Fase 2 TLS/permessi resta da dimostrare; B1 non autorizzato da questa review.

Verifica master dopo correzione ordinamento: **14 controlli stack reale
usa-e-getta passati**, insieme a filesystem27 e topology11. Approvata fase 1.
Integrazione gateway/proxy: due reti controllate, backend negato su tutti i
vhost, nessun nuovo accesso diretto Napay -> BTCPay. Si validano configurazioni
reali prima di eventuale restart locale gateway/egress; non usare avvio globale
che applica automaticamente migration Napay. B0 fase2 e B1 ancora non conclusi.

## Configurazioni effettive condivise

Integrato fix agente `2e6d368` come `e6acc82`, senza duplicare la correzione.
Master verifica compose orchestratore e 24 controlli compose sandbox; Squid
accetta la allowlist effettiva. Napay proxy/rete: commit `9334c2c3`.

Caddy adapt sulla configurazione reale ha mostrato redirect ordinati prima
al blocco backend. Redirect ora in handle catch-all, dopo handle del rifiuto;
nessuna modifica alle destinazioni. `tests/gateway-btcpay.cjs`, alimentato
con JSON di caddy adapt, verifica 22 casi inclusi controlli negativi con
redirect anticipato. Tutti i siti HTTP/HTTPS devono rifiutare la subnet
backend prima di risposte/proxy/redirect. Sintassi launcher e diff verificati.
Questi controlli non sostituiscono fase 2 TLS/permessi su servizi avviati.

## Avvio locale e trasporto reale

Stack persistente regtest avviato il 2026-11-12 con stato privato esterno in
BTCPAY_LOCAL_STATE; quattro servizi healthy, nessuna porta backend pubblicata.
Ricreati solo gateway ed egress, senza avvio globale/bootstrap/migration Napay.

Prove master effettivamente eseguite:

- Dalla rete egress Napay: Squid -> https://btcpay.local/api/v1/health,
  CA locale verificata, risposta synchronized=true.
- Stesso percorso senza CA: rifiuto curl60, nessun TLS bypass.
- Dalla rete backend edge: richieste HTTPS ai quattro host napay.local,
  wallet.local, pos.localhost e btcpay.local interrotte da Caddy. Con
  HTTP/1.1 curl52; con HTTP/2 curl92 (stream abort, non risposta applicativa).
- Host locale -> gateway HTTPS -> health regtest: synchronized=true.
- Disponibilita siti esistenti dopo riavvio: Napay302, POS200, wallet200.

Il primo probe negativo ammetteva solo52/56, quindi si e fermato sul92 di
HTTP/2. Ripetuto con HTTP/1.1 esplicito e IP effettivo edge: tutti quattro
rifiutati. Nessun errore mascherato come isolamento e nessuna chiamata a
endpoint finanziari reali. Non sono stati creati admin, utenti o API key
nell'istanza persistente. Matrice endpoint/permessi fase2 resta all'agente
sul suo stack usa-e-getta; B1 rimane non approvato fino alla review degli esiti.
Il trasporto di rete non equivale ancora a un client provisioning Napay.

## Regressione ripetibile del trasporto locale

Master riserva tests/btcpay-local-transport.sh: rende ripetibili le prove gia
eseguite sul regtest condiviso, senza creare admin/chiavi o cambiare servizi.
NAPAY_CA_FILE deve indicare CA locale esistente; nessun percorso personale
fissato nel codice. Controlla reti interne/identita attesa, TLS tramite proxy,
rifiuto senza CA e guardia backend sui quattro siti; usa solo nomi locali.
Non e prova dei permessi API ne del futuro worker B1.

## Review indipendente fase 2 e scelta P3

Master integra63c0c25 come cc6d36c e410e512 come e467390. Rieseguito
phase2.sh:22 controlli verdi, incluse sei risposte429 gestite rispettando
Retry-After. Verificati rimozione container/volumi/rete della sola istanza
usa-e-getta. Confermati store/chiavi isolati fra merchant, chiave revocata401,
assenza di privilegio mint da chiave merchant e nomi store non univoci.

Utente conferma P3; decisione9e33cc9 e B0-DECISIONE-P3.md sostituiscono P1.
Autorizzata proposta B1, non ancora codice/schema/worker: recovery delle
credenziali e test negativi sul ruolo admin restano gate del contratto.

Regressione trasporto effettivo: tests/btcpay-local-transport.sh,7 controlli
verdi. Primo run con cap-drop ALL non leggeva CA0600 (curl77); corretto
eseguendo client con UID/GID proprietario, senza allargare permessi del file
o ripristinare capability. Successivo run interamente verde. Script e diff
verificati; nessuna password/chiave o nuova identita nel regtest persistente.
