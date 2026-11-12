# SIP-022 B1a - Review master della busta credenziali

Data: 2026-11-12. Esaminati16e11c8c e1b6754e8 nel worktree CLA
napay-btcpay-b1a. Nessun codice B1a integrato nel checkout principale.

Master esegue runner dedicato:59 controlli verdi, lint helper incluso;
container senza rete, sola lettura, nessun DB o segreto persistente.
Decisione successiva utente opzione B compatibile con helper: il kind
onboarding_password resta identificatore, non una scadenza del segreto.

## B1a-RV1 - P2: trace interni contengono parti della busta

CredentialEnvelope::unwrap riceve parts decodificate senza SensitiveParameter.
Con zend.exception_ignore_args=0, una KEK errata produce eccezione il cui
getTrace conserva ciphertext e wrapped_dek binari negli argomenti privati,
anche se i parametri pubblici sono correttamente oscurati. Non e esposizione
di password o KEK in chiaro; viola il contratto di non includere la busta nei
trace. Correggere annotazione del parametro privato e verificare analoghi
confini interni. Aggiungere test ricorsivo sulle stringhe dei trace che
cerchi anche parti decodificate, non solo busta serializzata o base64.

Sonda indipendente: genera busta sintetica, decrypt con KEK errata, visita
ricorsivamente argomenti getTrace saltando oggetti SensitiveParameterValue;
confronto booleano con ciphertext decodificato conferma presenza. Nessun
valore cifrato o chiave stampato. Primo tentativo di serializzare il trace
non utilizzabile: SensitiveParameterValue non serializzabile; sostituito da
visita ricorsiva senza serializzazione e senza esposizione di dati.

## B1a-RV2 - P3: limite prima della decodifica

parse decodifica base64 prima di controllare limite del campo: input enorme
alloca copia binaria prima del rifiuto. Controllare tipo e lunghezza codificata
massima prima di base64_decode, poi mantenere controlli canonici e lunghezze
binarie attuali. Test sul rifiuto di input fuori limite. Non cambiare formato
busta, contesto, primitive crittografiche o politica dei segreti.

Fix e test assegnati a CLA nel suo write set; review prima dell'integrazione.
Nessun ostacolo architetturale rilevato nel doppio AEAD/AD/rewrap esaminato;
questa review non certifica schema DB, caricamento KEK o worker non implementati.
