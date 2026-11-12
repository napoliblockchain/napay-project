# SIP-023 R1 - Prima policy condivisa, sola lettura

- Master, 2026-11-12. Implementazione autorizzata dalla richiesta di proseguire.
- Nessuna migration, nuova registrazione, autoattivazione o invito implementato
  da questo micro-step: prima forniamo una dipendenza comune ai servizi C4.

## Contratto

File master `napay/components/identity/AccountEligibility.php`, metodi statici:

- `kind(int $userId): string`: `member_pf`, `member_pg`, `operator`,
  `platform_admin`, `unclassified`, `conflict`. Classificazione applicativa,
  non nuovi valori salvati o nuovi ruoli numerici.
- `isOperatorAccount(int $userId): bool`: account attivo/base, identita operatore
  coerente. Non concede grant e non richiede profilo abilitato: per usare un POS
  occorre anche verificare i flag e le assegnazioni C1 in ogni operazione.
- `merchantForManager(int $userId): ?int`: account attivo livello merchant,
  socio PG coerente, esattamente un merchant posseduto; restituisce solo quell'ID.
  Non e un'autorizzazione admin o allo sblocco di un POS.
- `qualifiedMerchant(int $merchantId): bool`: relazione univoca con account PG
  di livello merchant. Non sostituisce il controllo sull'attore e sul record.
- `canActivateMerchant(int $userId): bool`: account attivo/base, socio PG,
  nessun merchant gia presente. E un precontrollo di sola lettura; il futuro
  comando dovra riverificare sotto lock e proteggere l'unicita transazionale.

## Evidenze e fail secure

Usare solo evidenze positive gia persistite: MemberProfiles per socio PF/PG,
PosOperators per operatore; quest'ultimo non deve avere profilo/quote associative
ne merchant posseduti. Il solo livello 0 o la mancanza del profilo associativo
non rendono un account operatore. Conflitti, email ambigue dopo normalizzazione,
merchant multipli o record PG/PF non coerenti non danno capacita operative.
Account senza evidenze resta unclassified, non viene trasformato in socio PF.

Il gestore e lo stesso account PG dopo autoattivazione; nessun account nuovo
per questo passaggio. Non usare merchants[0]. Account inattivo non esercita
capacita, ma lo stato di quota associativa non viene usato come blocco implicito.
PG coerente richiede ragione sociale UTF-8 non vuota e non oltre 250 caratteri,
come nel modello associativo; il solo flag is_corporate non completa il profilo.
Errori/schema DB mancanti propagati al chiamante: niente fallback permissivo.
Nessuna cache di classificazione o scrittura di dati.

## Uso C4 e confini

L'agente C4 riusa la policy, non ne copia le query. I controlli admin/merchant,
CSRF, scope record-level e lock sono sempre responsabilita delle action/service.
Abilitazioni/concessioni richiedono identita coerente; disabilitazioni o revoche
amministrative di dati incoerenti richiedono un percorso esplicito di riduzione
privilegi, non l'elusione della policy per concedere accesso.

Questo helper non risolve ancora: scopo account e nuovi flussi di iscrizione,
filtri soci/quote, collisioni concorrenti email, vincolo DB gestore unico,
consumo invito e aggiornamento di C2. Questi sono micro-step successivi.
Prima del loro completamento non dichiarare SIP-023 interamente implementato.

## Verifica

Implementato: Napay `5c1fd920`, test `00afe16a`. Eseguiti 24 controlli su MySQL
usa-e-getta, bootstrap `already-complete`, sintassi PHP/shell e review indipendente.
Corretto un finding su PG con ragione sociale mancante; casi negativi aggiunti.
Nessuna integrazione nei controller esistenti o nuova migration eseguita.
[Handoff operativo per C4](HANDOFF-AGENTE-NAPAY.md).

Test esclusivamente su MySQL usa-e-getta: identita sconosciuta, PF, PG,
operatore, sovrapposizione socio/operatore, PG con merchant univoco, account
inattivo, merchant multipli ed email ambigue. Nessun test modifica la sandbox.
