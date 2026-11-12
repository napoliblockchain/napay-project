# SIP-021 - Login operatore R1 e serializzazione D3

Master, 2026-11-12. Implementazione dopo review C4-RV2; nessun edit classi C4.

## Contratto prima del codice

- Il login API non e il login generico Napay. Email/password valide non bastano:
  solo account base attivo, positivo `AccountEligibility::isOperatorAccount`,
  profilo POS abilitato e merchant qualificato. Nessun grant obbligatorio per
  login: catalogo puo essere vuoto. Soci/admin/gestori non accedono al POS.
- Nessuna creazione o migrazione implicita di profili per account esistenti.
  Vecchi account senza profilo coerente devono seguire la futura procedura invito.
- Credenziali, profilo disabilitato/assente, identita incoerente o merchant
  non qualificato: medesimo 401 `invalid_credentials`, senza token persistito.
  Errori DB/schema mantengono 503, non diventano assenza di profilo.
- `PosApi::createSession` ricontrolla e inserisce nella propria transazione
  READ COMMITTED (solo la transazione, non configurazione globale).
  Ordine lock: merchant, profilo operatore, utente, sessione inserita.
  Merchant da lookup iniziale e solo hint: il profilo bloccato deve ancora
  appartenergli. Utente riletto sotto lock, hash password uguale a quello
  appena verificato dal LoginForm; R1 e flag ricontrollati prima dell'INSERT.
- D3 C4 mantiene stesso ordine merchant/profilo e lock fino a commit della
  disabilitazione/revoca. Se login vince, disable successivo vede e revoca token;
  se disable vince, login successivo trova profilo disabilitato e non inserisce.
- `findActiveSession` applica anche R1, profilo abilitato e merchant qualificato
  a ogni richiesta: token legacy socio/admin/gestore non da accesso al catalogo.
  Profilo disabilitato = 401 `invalid_token`, non catalogo vuoto 200.
- Logout resta possibile anche con account/profilo disabilitato: la sua lookup
  scoped al client non dipende da findActiveSession.
- Nessuna modifica a password, ruolo, sessione browser Napay, TTL o token shape.
  Throttle fallimenti copre anche account non eleggibile; reset solo a successo.

## Verifiche richieste

Nuove fixture esplicite operatori dedicati e merchant PG; i vecchi test che
loginavano come admin/gestore devono ora attendersi 401. Verificare soci base,
profilo assente/disabilitato, conflitti, merchant non qualificato, password
cambiata tra verifica e inserimento, stato aggiornato durante attesa lock,
login concorrente a disable e vecchio token inutilizzabile dopo riabilitazione.
Nessun seed o riavvio della sandbox condivisa. Test SQL del protocollo precedono
integrazione della fix C4; non sostituiscono la futura prova C4+API congiunta.

## Consegna verificata

Napay `6487abbd`, dipendenza R2 `121fe3a2`. POS documentazione/OpenAPI
`9984225` (wire invariato; nessun nuovo endpoint).

Eseguiti dal master, tutti su stack usa-e-getta:

- `tests/docker/pos-session-eligibility.sh`: 119 controlli API e protocollo
  SQL D3, inclusi test in due processi, nessun token nei log Apache/applicativi;
- `tests/docker/pos-terminals.sh`: 177 controlli HTTP/DB catalogo;
- `tests/docker/pos-catalog.sh`: 51 C1, 62 login, 32 logout;
- `tests/docker/runtime.sh`: suite completa, restart del web e bootstrap no-op;
- sintassi PHP 8.3.36 e shell, controllo diff; nessun PHPStan configurato;
- struttura OpenAPI POS: 45 riferimenti locali validi.

La race D3 verificata usa il protocollo SQL concordato, **non le classi C4**
che restano da correggere/integrare. Dopo i cherry-pick nel worktree C4 occorre
la prova congiunta reale C4/API. Nessun browser/seed/migration sulla sandbox.
Login POS con account socio/admin/gestore ora rifiutato intenzionalmente;
non creare profili impliciti per recuperare il precedente test browser admin.
