# SIP-022 - Decisione utente: password tecnica conservata (opzione B)

Data: 2026-11-12. Decisione esplicita dell'utente dopo chiarimento
sull'esperienza merchant: opzione B, con recupero amministrativo eccezionale.
Sostituisce l'ipotesi di eliminare la password tecnica dopo onboarding e la
precedente proposta di rotazione ordinaria manuale tramite BTCPay.

## Esperienza e credenziali

- Il merchant usa esclusivamente Napay, con le proprie credenziali Napay.
  Non riceve password o chiavi BTCPay e non deve accedere alla sua interfaccia.
- Password tecnica BTCPay casuale, distinta dalla password Napay, conservata
  cifrata anche dopo il completamento dell'onboarding. Cambiare password
  Napay non cambia questa credenziale o la proprieta degli store.
- Solo worker con utente DB dedicato puo leggere/scrivere tabella credenziali
  e accedere alla KEK esterna. Web/POS non ricevono password, chiavi, KEK o
  accesso alla tabella, neppure per una schermata amministrativa.
- Rimane P3: identita tecnica e chiave limitata distinte per merchant,
  provisioner senza permessi globali sulle impostazioni del server.
- Il kind onboarding_password del contratto busta B1a puo restare come
  identificatore tecnico stabile; non significa piu segreto temporaneo.
  Nessuna cancellazione automatica al passaggio key_saved/synced.

## Rotazione e recupero

Rotazione ordinaria gestita da Napay/worker tramite autenticazione tecnica
del merchant, senza interventi su BTCPay da parte del merchant. Policy di
periodicita e autorizzazioni di avvio amministrativo da definire nel contratto
worker; questa scelta non inventa una cadenza automatica.

Prima di revocare chiave precedente: nuova chiave verificata sul tenant
corretto e salvata durevolmente. Il contratto deve coprire coesistenza
transitoria vecchia/nuova generazione, crash, lease/CAS, ripresa e revoca
ritardata; non basta sovrascrivere l'unica riga e perdere il riferimento
alla vecchia chiave. Nessun retry illimitato o escalation di privilegi.

Account tecnico bloccato, password cambiata esternamente o stato non
riconciliabile: sospensione lavori coinvolti con errore controllato e
recupero amministrativo esplicito, tracciato, per la sola identita gia
mappata. Non adottare/reset automatici di utenti remoti non riconosciuti.
Revoca della chiave non disattiva automaticamente il merchant Napay.

La password permanente amplia l'impatto di una compromissione: obbligatori
isolamento worker/DB, cifratura autenticata con binding tenant/istanza,
segreti assenti da UI/log/outbox/argomenti processi e rotazione KEK separata
dalla rotazione delle chiavi BTCPay.

## Stato implementazione

Decisione documentata, non funzionalita gia disponibile. CLA aggiorna
B1-PROPOSTA nel proprio write set. B1a cifratura resta compatibile: helper
puro non decide conservazione/cancellazione. Schema/worker/rotazione reale
richiedono contratto e review master prima del codice relativo. Nessun
segreto persistente generato o cambiato da questa decisione.
