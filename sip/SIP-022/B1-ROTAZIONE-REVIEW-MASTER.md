# SIP-022 - Review test rotazione decisione B

Data: 2026-11-13. Consegna CLA9b78d00,14c414b,8519883.
R1-R4 nel test coerenti con contratto: seconda chiave dallo stesso utente,
store/app invariati, isolamento merchant, vecchia valida fino a revoca,
nuova utilizzabile dopo revoca. I30 PASS sono dichiarati da CLA: master
non ha ancora rieseguito questa versione, in attesa del fix seguente.

## RV1 - P2: token negli argomenti del processo

La sonda DELETE /api/v1/api-keys/$key3 interpola il valore segreto nella URL
che api() passa fra argomenti di docker run/curl. Header sono correttamente
in file, ma la URL non lo e. Usare file curl-config privato per evitare il
valore in argv, senza stampare URL complete nei messaggi retry. Non stampare
body/header o Docker inspect contenenti credenziali. Solo stack usa-e-getta.

## Precisazione degli esiti

Il400 apikey-not-found dimostra fallimento della specifica chiamata con Basic
e valore chiave usato come identificativo; non dimostra da solo impossibilita
di ogni altra API di recupero. Distinguere fatti osservati, assenza elenco
nell'OpenAPI esaminata e scelta prudenziale di recupero amministrativo.
Non autorizzato ampliare privilegi per far riuscire la sonda.

Fix assegnato a CLA nel proprio write set regtest; master non modifica lo
script concorrente. Password tecnica permanente e doppia generazione restano
quelle gia approvate, nessuna modifica al worker o allo schema autorizzata.
