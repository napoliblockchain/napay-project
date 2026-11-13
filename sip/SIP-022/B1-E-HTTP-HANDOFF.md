# SIP-022 B1 - Handoff client HTTP provisioning (agente Napay, 2026-11-13)

- Incarico master (file di coordinamento), SIP-022/B1-PROPOSTA §9.
- Worktree `napay-worktrees/napay-btcpay-http`, branch
  `feature/v2-btcpay-b1e-http`, base `258a0e9c`. Commit: `7837cad5`
  (client + eccezione), `d9decd4b` (test, fixture, runner).
- Nessuna modifica a `payments/*`, flusso quote o legacy; nessun gateway,
  regtest persistente, DB, configurazione, segreto o bootstrap.

## Scelta

`payments/BTCPay.php` usa l'SDK Greenfield: bufferizza tutta la risposta
(nessun limite di corpo/header), autentica solo con `token`, non espone
`Retry-After` e i suoi errori contengono URL/corpi. Il client usa quindi
cURL diretto con le stesse opzioni di trasporto e **riusa `Egress::proxy()`**
(qui obbligatorio: assente o non valido = `invalid_config`).

## Componente

`components/btcpay/provisioning/ProvisioningHttpClient.php`
- `new (origin, ?caFile)`: solo `https://host[:porta]`, CA assoluta leggibile.
- `withKey(method, path, ?body, apiKey)` e `withBasic(method, path, ?body,
  user, password)`: credenziali e corpo per richiesta, `SensitiveParameter`
  anche sul corpo; restituiscono `status`, `retry_after` (grezzo, header
  ripetuti uniti), `json`.
- Metodi GET/POST/PUT/DELETE; percorsi solo `/api/v1/...` con caratteri
  ammessi (email tecnica come segmento), niente query, `%`, segmenti
  vuoti o `.`/`..`; corpo JSON <= 1 MiB, GET senza corpo.
- Trasporto: CONNECT sul proxy, `CURLOPT_NOPROXY = ''` (verificato: senza,
  `no_proxy` dell'ambiente fa connettere direttamente), solo HTTPS, TLS 1.2+,
  verifica CA e hostname, nessun redirect, timeout 5/15 s, header <= 16 KiB,
  corpo <= 1 MiB con interruzione, HTTP/1.1, niente `Expect`.
- Nessun ritentativo. Eccezione `ProvisioningHttpException` a codici fissi:
  `invalid_config`/`invalid_request` = nulla inviato (`notSent()`);
  `outcome_unknown` = trasporto, TLS, limiti, troncamento, redirect, JSON non
  valido o non oggetto/lista: mai prova di mancata esecuzione.

## Test

`tests/docker/btcpay-provisioning-http.sh`: **94 PASS** (~25 s). CA e
certificati usa-e-getta generati dal runner (una CA fidata, una estranea),
server HTTPS e proxy CONNECT con allowlist nello stesso container senza
rete e in sola lettura; credenziali fittizie. Coperti: configurazione e
richieste rifiutate senza traffico; consegna solo via proxy anche con
`no_proxy=*`, il proxy vede solo host:porta; header di autorizzazione e
corpo integri (digest); stati 4xx/5xx/429 con Retry-After (secondi, data,
ripetuto) dopo un solo tentativo; redirect non seguito; corpo di 1 MiB
esatto accettato, oltre/header grandi/troncato/malformato/scalare/non HTTP/
chiusura: esito ignoto; hostname errato, CA estranea, CA non configurata;
timeout totale ~15 s e di connessione ~5 s; nessun segreto nei frame del
client. Controprova (mutazioni): senza SensitiveParameter, con redirect,
senza `NOPROXY` o senza limite del corpo la suite fallisce.

## Correzione review master (runner)

- `d51ca713`: certificati e chiavi di prova restano in cartella 0700 con file
  0600; i container girano con uid/gid dell'host (come i test di trasporto
  B0), senza allargare permessi né `DAC_OVERRIDE`. **94 PASS**.

## Limiti

- Gli errori TLS sono `outcome_unknown` anche se la richiesta non è partita
  (scelta prudente richiesta: nessuna falsa prova).
- Interpretazione degli stati, Retry-After (RetryPolicy) e riconciliazione
  restano al chiamante; nessuna query string supportata.

## Review Master

Client e runner privato verificati **94 PASS**, anche sul branch integrato.
Commit integrati `f6824e5e`, `3a8bc1a9`, `f413d94e`. Nessuna modifica al
flusso quote o chiamata al BTCPay persistente/produzione. Trasporto worker
pronto; orchestratore provisioning e servizio daemon ancora da implementare.
