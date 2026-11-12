# SIP-022 B0 - Decisione P3 e confini B1

Data: 2026-11-12. Decisione esplicita dell'utente dopo consegna fase2:
**P3: chiavi separate per merchant**. Sostituisce P1 nelle proposte e nella
prima review B0; quei documenti conservano la cronologia, non autorizzano
piu il provisioning P1 con permessi sulle impostazioni server.

## Credenziali e proprieta

- Provisioner dedicato: cancreateuser e canviewusers, separato dalla chiave
  per le quote associative. Non aggiungere canmodifyserversettings,
  canmanageusers o unrestricted per aggirare un errore.
- Un utente tecnico BTCPay per merchant; email deterministica dal mapping
  casuale sul dominio btcpay-merchants.jamprojects.it, mai email personale.
- Il merchant tecnico crea la propria chiave mediante autenticazione Basic
  solo su HTTPS verificato. Chiave limitata a canmodifystoresettings nel suo
  contesto: store di sua proprieta, merchant unico Owner, niente provisioner
  membro degli store. Fatturazione futura richiedera revisione permessi separata.
- Chiave provisioner solo al worker come secret esterno; chiavi merchant
  cifrate, revocabili, associate a istanza/merchant, mai browser, POS o log.
  Chiave di cifratura esterna al DB e a git, non riuso di cookie/hash key.

## Crash e riconciliazione da coprire nel contratto B1

La vecchia ipotesi "password mai persistita" non copre il crash dopo creazione
utente e prima di salvataggio chiave. B1 deve definire stato onboarding:
password casuale cifrata con la stessa separazione dei segreti, salvata prima
della chiamata remota, accessibile solo al worker, eliminata quando la chiave
merchant e salvata durevolmente. Non esporla al titolare o ai servizi web/POS.
Nessuna password in chiaro nel DB, outbox, errori o comandi/log di processo.

Dopo timeout: riconciliare email e identita remota del mapping. Utente remoto
preesistente non mappato non viene adottato, resettato o modificato. Password
non valida, stato ambiguo o chiave creata ma non salvata richiedono recovery
esplicito; non generare infinite chiavi. Il contratto deve coprire anche crash
fra creazione chiave e persistenza senza assumere idempotenza dell'endpoint.

Nomi store/app non sono univoci: mapping locali univoci, serializzazione per
risorsa, stato ambiguo dopo POST senza esito certo, niente retry cieco. Gestire
429 con Retry-After e attese limitate, 401/403 senza escalation automatica.
Rotazione e revoca devono specificare comportamento degli eventi pendenti e
non dichiarare la disabilitazione del merchant solo perche una chiave e revocata.

## Assegnazione e gate

Agente Napay: sola proposta B1-PROPOSTA.md nel worktree orchestratore.
Master: review test fase2, integrazione, schema/migration e file condivisi.
B1 non ancora autorizzato al codice. Nessun segreto persistente generato e
nessuna creazione su BTCPay produzione o sul regtest condiviso in questo passo.
Test fase2 usa-e-getta e prove TLS reali sono evidenze distinte, non un test
end-to-end del futuro worker. Inviti C4 restano indipendenti dal provisioning.
