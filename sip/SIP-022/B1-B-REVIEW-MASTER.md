# B1b - Review master (2026-11-13)

Consegna: Napay `ff7d1c73`, `36ce8fcc`; handoff CLA `2ff65e1`.
Master ha eseguito il runner usa-e-getta: C1 e 144 controlli schema/GRANT
verdi, bootstrap no-op. Nessuna integrazione o DDL condivisa autorizzata.

## RV1 - Verificatore delle espressioni altera i literal SQL (bloccante)

`m261113_120000_create_btcpay_provisioning_schema::clause()` elimina spazi,
backtick e backslash anche dentro le stringhe. Riproduzione con PHP8.3.36
in container network-none: espressioni con `state = 'current'` e
`state = 'cur rent'` vengono normalizzate allo stesso valore. La seconda
rende sempre NULL il marker per gli stati ammessi: il verificatore potrebbe
accettare uno schema senza unicita effettiva delle credenziali current.

CLA deve preservare i literal/regex/escape, normalizzando soltanto i token
esterni e gli introducer charset ammessi. Test DB richiesti: marker con
spazio, dominio con spazio, regex con spazio/backslash; deriva rifiutata
prima di qualunque DDL e replay dello schema corretto ancora valido.
Finding trasmesso nel file condiviso; fix nello stesso worktree B1b.

## Esito Finale - Approvata, Integrazione Isolata

RV1 corretta da `ddcfadbc`/`64d042fa`: letterali preservati, normalizzazione
solo esterna, escape information_schema trattati separatamente. Master ha
rieseguito il runner: C1 **55**, B1b **148 PASS**, comprese le quattro derive.
Integrazione su `feature/v2-btcpay-b1-integration`, base UI `3c72454c`:
`6602f348`, `10630e0b`, `e4d983bd`, `7be3a3e0`. File consegnati identici;
`runtime.sh` completa verde sul branch integrato, exit0, restart con DB
preservato/bootstrap no-op. Harness iniziale corretto predisponendo vendor
locale e directory runtime/assets ignorate necessarie ai mount read-only.

Nessuna migration nel checkout live: il suo hash bootstrap e i suoi GRANT
schema-wide impongono prima la separazione dei ruoli DB. Sandbox principale
verificata ancora ready, nessun backfill/provisioning/segreto reale aggiunto.
Prossimo codice CLA: coda worker secondo `B1-C-CODA.md`; bootstrap/ruoli master.
