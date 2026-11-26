# SIP-022 B1 - Handoff RetryPolicy (agente Napay, 2026-11-13)

- Incarico master (file di coordinamento): SIP-022/B1-PROPOSTA §4.
- Worktree `napay-worktrees/napay-btcpay-retry`, branch
  `feature/v2-btcpay-b1d-retry`, base `2c7f116a`. Commit: `954c64d3`
  (componente), `d91a0cda` (test e runner).
- Nessun HTTP, DB, configurazione, credenziale o bootstrap.

## Componente

`components/btcpay/provisioning/RetryPolicy.php`, unico metodo pubblico
`decide(?retryAfter, attempt, now)` -> `next_attempt_at`, `deferred`,
`server` (Retry-After valido usato). Jitter iniettabile.

- Retry-After: secondi interi non negativi (zeri iniziali e spazi/tab ai
  bordi ammessi) o IMF-fixdate rigorosa (giorno della settimana coerente,
  `GMT`, data reale, secondo 60 ammesso); formati obsoleti RFC 850/asctime,
  segni, decimali, cifre non ASCII, newline: non interpretabili.
- Prossimo tentativo = max(scadenza server, adesso + backoff); data passata
  = solo backoff. Backoff 30 s * 2^(n-1) + jitter 0..1/5, mai oltre 1 h.
- Oltre 24 h: `deferred` (solo admin, coerente con la coda B1c). Valori
  enormi validi saturano a `PHP_INT_MAX`, mai fallback breve; somma al
  limite dell'intero senza overflow.
- Tentativo 1..1000 (limite della coda), orologio >= 0, jitter fuori
  intervallo: codici fissi.

## Test

`tests/docker/btcpay-provisioning-retry.sh`: **71 PASS** (runtime Napay,
rete assente, sola lettura). Controprova: con valori enormi trattati come
non validi, o senza il massimo fra server e backoff, la suite fallisce.

## Correzione review master (orologio al limite)

- `3bcb3461`: orologio oltre `PHP_INT_MAX - 3600` rifiutato
  (`invalid_now`), mai saturato: `now + backoff` restava intero solo fino lì
  e saturare accorcerebbe l'attesa minima.
- `40604ac0`: regressione al bordo con header assente, secondi e data:
  limite esatto = intero, limite+1 e massimo rifiutati. **80 PASS**; il
  componente precedente fallisce sul primo caso oltre il limite.

## Limiti

- Il massimo di tentativi per lavoro (es. 10 nella SIP) non è qui: resta
  all'orchestratore con `ProvisioningJobs::fail`.
- Header ripetuti o liste: al client HTTP passare un solo valore; una lista
  risulta non interpretabile (backoff).
