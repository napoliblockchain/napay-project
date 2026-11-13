# SIP-021 fase 2 - Apertura esclusiva POS: contratto (PROPOSTA)

- Autore: agente Napay (CLA), 2026-11-13. POS assegnato dall'utente all'agente
  Napay; il master ne è informato (file di coordinamento).
- Base: SIP-021 (decisioni 5-6, criteri di accettazione), bozza OpenAPI
  `pos/v2/docs/pos-api.openapi.json` (percorsi e campi invariati),
  `NAPAY-CONTRACT.md` sezione "Lock e revoca".
- Stato: **APPROVATO dall'utente il 2026-11-13** (decisioni sezione 7: 1 sì, 2 sì, 3 sì).

## 1. Modello

Nuova tabella Napay `pos_terminal_openings` (migration nuova, additiva):

| Colonna | Note |
| --- | --- |
| `id` | PK interna |
| `public_id` | UUID v4, è l'`opening_id` dell'API |
| `terminal_id`, `merchant_id` | FK `pos_terminals`, `merchants` |
| `session_id`, `user_id` | FK `pos_operator_sessions`, `users`: l'apertura appartiene a **una sessione** (token), non solo all'utente |
| `instance_id` | UUID v4 generato dal POS per istanza/scheda |
| `generation` | intero per terminale, cresce a ogni nuova apertura; UNIQUE (`terminal_id`, `generation`): è la prova di fencing |
| `state` | `active`, `released`, `revoked` |
| `active_marker` | colonna generata `CASE WHEN state='active' THEN 1 END`, UNIQUE (`terminal_id`, `active_marker`): **al massimo una apertura attiva per terminale anche contro scritture fuori dal codice** |
| `idempotency_sha256`, `request_sha256` | UNIQUE (`session_id`, `idempotency_sha256`) |
| `opened_at`, `last_seen_at`, `closed_at`, `closed_reason`, `closed_by` | `closed_reason`: `released`, `logout`, `manager_unlock`, `owner_ineligible` |

Nessun dato di pagamento o wallet; nessuna modifica alle tabelle C1/sessioni.

## 2. Validità di un'apertura

Un'apertura è **utilizzabile** solo se, alla richiesta: stato `active`;
sessione del chiamante = sessione dell'apertura e ancora valida
(`findActiveSession`); `instance_id` e `generation` coincidono; profilo,
grant del negozio, terminale e merchant ancora abilitati/qualificati.
Altrimenti: apertura altrui o fuori scope **404**; propria non più valida
**409 `opening_closed`**. Nessuna operazione la "resuscita".

## 3. Operazioni operatore (API POS, stessi header di sessioni/catalogo)

| Operazione | Comportamento |
| --- | --- |
| `POST /terminals/{terminal_id}/openings` + `Idempotency-Key` (UUID v4) + `{instance_id}` | In una transazione READ COMMITTED, lock nell'ordine C4 (merchant, profilo, utente, negozio, grant, terminale, sessione), ricontrollo scope, poi lettura dell'apertura attiva del terminale. Libera: nuova `generation` = max+1, **201** con `{id, terminal_id, instance_id, generation, state}`. Occupata da apertura utilizzabile: **409 `terminal_in_use`**, anche stesso utente/altra scheda; nessuna sostituzione. Replay stessa chiave e stesso corpo: **200** con l'apertura originale se ancora attiva, altrimenti **409 `opening_closed`**; stessa chiave, corpo diverso: **409 `idempotency_conflict`**. |
| `GET /openings/{id}` | Solo verifica (sezione 2), **200** o 404/409. Non acquisisce né riprende. |
| `POST /openings/{id}/heartbeat` `{instance_id, generation}` | Verifica, aggiorna `last_seen_at`, **204**. Serve solo a mostrare al manager l'ultimo contatto. |
| `POST /openings/{id}/release` `{instance_id, generation}` | Chiusura normale del titolare: `released`, **204**; replay su apertura già chiusa dalla stessa sessione **204**. Non è lo sblocco forzato. |
| `DELETE /sessions` (esistente) | Nella stessa transazione chiude anche le aperture attive della sessione (`logout`). |

Limiti: aperture 30/min per sessione; heartbeat 6/min per apertura; errori e
formato come catalogo (`validation_failed`, `invalid_token`, `rate_limited`,
`backend_unavailable`), `no-store`.

## 4. Sblocco forzato (backoffice Napay, C4)

Pulsante nella pagina terminali di `pos-management`: POST con CSRF, solo
admin o gestore del merchant del terminale (Scope C4). Nella transazione con
l'ordine dei lock C4: apertura attiva -> `revoked`, `manager_unlock`,
`closed_by`; registro attività senza token. La pagina mostra operatore,
apertura e ultimo contatto. Dopo lo sblocco ogni richiesta della vecchia
apertura riceve 409 e non può creare richieste TTS (fase 3 verificherà
l'apertura con la stessa funzione).

## 5. Revoche e crash

- Disabilitazione operatore/profilo (C4 D3) revoca già le sessioni: le loro
  aperture diventano inutilizzabili (sezione 2).
- Revoca di grant, terminale disabilitato o merchant non più qualificato:
  stessa regola.
- **Nessuno sblocco per heartbeat scaduto** (SIP-021). Crash o rete persa:
  la stessa scheda dopo refresh continua (il POS conserva apertura,
  istanza e generazione nella propria sessione server); altrimenti sblocco
  del manager.

## 6. Lato POS (`pos/v2`)

Selezione di un terminale dal catalogo -> apertura; dati dell'apertura solo
nella sessione server POS; heartbeat ogni 30 s tramite endpoint POS con
CSRF; chiusura esplicita e al logout; 409 mostrati come "POS occupato" o
"apertura terminata, rientra". Nessun lock nel browser.

## 7. Decisioni dell'utente (2026-11-13)

1. **Apertura il cui titolare non può più agire** (sessione scaduta dopo
   12 h o revocata, profilo/grant/terminale disabilitati): un'altra
   acquisizione la può chiudere automaticamente (`owner_ineligible`)?
   Non è un takeover di un dispositivo vivo: quel titolare non può più fare
   richieste. **Approvato: sì** (`owner_ineligible`).
2. Heartbeat ogni 30 s, solo informativo. **Approvato.**
3. Il gestore merchant può sbloccare solo i POS del proprio merchant, l'admin
   tutti (SIP-021 decisione 6): pulsante in `pos-management` con conferma a
   schermo, CSRF e registro attività, nessuna email. **Approvato.**

## 8. Test previsti (DB usa-e-getta)

Due acquisizioni concorrenti reali (processi/connessioni): una 201, una
409; replay e conflitto di idempotenza; seconda scheda stesso utente 409;
heartbeat/release/GET con generazione vecchia, altra istanza, altra
sessione: 409/404; sblocco manager poi vecchia apertura 409 e nuova
acquisizione 201 con generazione maggiore; operatore non può sbloccare,
gestore di altro merchant 404; logout chiude l'apertura; disable/grant
revocato rende l'apertura inutilizzabile; vincolo DB rifiuta una seconda
`active` anche con INSERT diretto.
