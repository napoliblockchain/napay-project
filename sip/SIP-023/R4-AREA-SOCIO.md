# R4 - Area Socio In Consultazione

Richiesta utente 2026-11-14. Implementazione separata da BTCPay/POS.

- Soci PF/PG attivi secondo AccountEligibility, anche senza merchant:
  elenco e download dei verbali, quota/stato e storico propri gia esistenti,
  ricevute stampabili dei soli pagamenti propri con stato paid.
- Nessun requisito aggiuntivo di quota valida per la consultazione:
  lo stato quota resta visibile, non modifica identita o permessi merchant.
- Admin conserva backoffice e ricevute esistenti. Soci non accedono a
  elenco soci, pagamenti altrui, tabelle, export o mutazioni associative.
- Riutilizzare AssociationController e viste, non duplicare servizi.
  Menu Verbali nella propria area; creazione/modifica solo admin.
- Ricevuta filtrata server-side per proprietario/stato prima del rendering;
  ID altrui, inesistente o manomesso restituisce 404. Operatori POS e
  account non soci negati, ospiti al login. Documenti con Cache-Control
  private, no-store. Nessuna modifica schema, dati o configurazione.

Test HTTP/DB isolati: PF, PG senza merchant, gestore PG, operatore,
account non classificato, identita disabilitata/conflittuale, guest;
link diretti e ID altrui, PDF, escaping, no pulsanti scrittura,
metodi/CSRF invariati, regressioni backoffice e quota.

## Consegna Verificata

2026-11-14: codice `1c0bebd4`, test `c2ee7b71`, integrati nel branch
Napay principale tramite fast-forward (base utente `4df5b5e8` preservata).
Allineati anche nel branch BTCPay isolato: `e2f53014`, `e16559dc`.

- **135 PASS** portale socio HTTP/DB: PF, PG senza merchant e gestore,
  operatori/account non soci negati, disabilitazione e profilo incoerente,
  PDF senza cache, ricevute stampabili con ritorno alla propria area.
- Prova record-level con ID cifrato valido nella stessa sessione:
  pagamento spostato su altro proprietario ->404; pending ->404 e link
  assente. Dati modificati esclusivamente nel database usa-e-getta.
- Runtime completa verde: backoffice40, scritture81, quota40, webhook34,
  Bitcoin34 e regressioni identita/API; restart DB persistito e bootstrap
  no-op. PHP lint e diff verificati; nessuna automazione browser.
- Checkout servito aggiornato senza riavvio o migrazione. Readiness
  condivisa verificata e hash dei sorgenti montati corrispondenti.

Ricevuta HTML con stampa/salvataggio PDF del browser (servizio esistente),
non nuovo generatore PDF. Nessun login con credenziali dell'utente reale;
collaudo autenticato eseguito con identita fittizie nel test isolato.
