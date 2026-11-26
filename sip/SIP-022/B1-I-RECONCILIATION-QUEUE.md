# W3d - Coda Di Riconciliazione GET-Only

Contratto master 2026-11-14, prima del codice. Nessun daemon/deploy.

- API nuova claimReconciliation(instance,kinds), limitata a store_link e
  pos_link. Solo reconcile_required dovuti, lease assente/scaduta; mai
  deferred. Marker null o coerente col tipo; marker estranei non reclamati.
- Claim assegna owner/version/lease ma MANTIENE reconcile_required e ogni
  marker. Restituisce reconciling=true: non trasforma il job in running.
  Per questo checkpoint/advance normali restano impossibili: nessun POST.
- prepareReconciliation: callback nella TX interna con fencing W3a e tempo
  fresco. Non cancella marker, non permette transazioni esterne.
- retryReconciliation: next_attempt_at futuro, lease rimossa e marker
  conservato. Oltre soglia policy puo diventare deferred, mai auto-claim.
- succeed puo chiudere una riconciliazione con callback atomico che adotta
  il solo marker unico verificato; reconcile conserva incertezza/marker.
  Il significato del risultato GET resta negli executor/Steps approvati.
- Tentativi esauriti: failed conservando prova in_flight, nessun nuovo POST.
  Account/key reconciliation A-r non e inclusa in questa prima API.

Test worker DB ristretto: due claim concorrenti, lease/version/owner stale,
checkpoint normale rifiutato, marker conservati, callback rollback/lease
scaduta, attesa/deferred, cap tentativi, operation di altro tipo ignorata,
adozione atomica. Vecchie suite coda63/fencing18 devono restare verdi.
CLA W3c non usa ancora queste API: attivazione del percorso dopo review.

## Implementazione Verificata

2026-11-14: codice `35eb4b0a`, test `12b64206`, branch isolato master.
**27 PASS** su MySQL reale con worker ristretto; gare a due processi,
marker conservati, nessuna transizione POST, rollback e adozione atomica.
Regressioni: coda **63**, fencing **18**, executor account **37** PASS.
Lint PHP/shell e diff verificati. Nessun HTTP reale, migrazione o deploy;
executor link e routing CLI non usano ancora queste primitive.
