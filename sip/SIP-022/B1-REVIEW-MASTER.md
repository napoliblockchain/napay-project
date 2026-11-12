# SIP-022 B1 - Review master

Data: 2026-11-12. Esaminati594485f e cbdd37f, importati come9fe7de5 e2274edd.
P3 e separazione utenti DB confermati dall'utente; codice B1 non approvato.

## Correzioni richieste

1. **P2, duplicati dopo timeout.** Sezione3.2 consente nuovo POST quando GET
   non trova marker. La prima richiesta puo essere ancora in esecuzione e
   completare dopo GET: si creano due store/app. Anche zero risultati deve
   restare reconcile_required finche non esiste evidenza conclusiva; nessun
   timeout/counter locale dimostra da solo assenza dell'effetto remoto.
2. **P2, lease non equivale a fencing remoto.** Un worker scaduto puo essere
   ancora dentro una chiamata. CAS lease-owner/versione sugli esiti impedisce
   scrittura obsoleta locale, non secondo effetto remoto. Operazione in-flight
   scaduta va ambigua e riconciliata, non automaticamente rimessa in POST.
3. **P2, outbox atomica incompatibile con GRANT proposti.** Web solo SELECT
   su tutte le tabelle B1 non puo inserire evento nella transazione R3b/store/
   terminale. Limitare web a INSERT outbox e SELECT stati necessari, mantenendo
   zero privilegi sulle credenziali. Payload mai contiene segreti; worker
   rivalida entita/tenant/stato dal DB prima delle concessioni remote.
4. **P2, attesa429.** Non troncare Retry-After a300 anticipando il prossimo
   tentativo. Header valido oltre limite comporta defer senza chiamata prima
   della scadenza, oppure stato che richiede intervento. Definire parsing
   secondi/data HTTP, fallback e limiti senza busy retry.
5. **P3, envelope incompleto.** Testo prevede DEK per segreto, tabella una sola
   chiave dati: specificare envelope indipendenti per password/API key,
   nonce/tag/AD e versione KEK, evitando riuso nonce o identita ambigua.

Rotazione merchant resta decisione aperta. Non autorizzato reset automatico di
utenti remoti preesistenti. Vecchio createStore sincrono verra sostituito nel
passo master di integrazione outbox, non usato come fallback; valori legacy
settings non devono essere letti dal worker ne eliminati senza revisione dati.

Correzioni assegnate a CLA solo su B1-PROPOSTA.md. Nessun timestamp migration
B1 o privilegio applicato; nessun provisioning reale autorizzato dalla review.
