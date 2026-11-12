# SIP-026 - Napay: dashboard con grafici per ruolo

- Stato: OPEN - proposta dell'agente Napay su richiesta dell'utente (2026-11-12);
  numero confermato dal master e inserito nell'indice (2026-11-12).
- Area: Backoffice / UI / Reportistica.
- Repo: `napay`; orchestratore per documentazione.
- Branch target: `feature/v2-yii2-php83-docker`.
- Segnalato: 2026-11-12.
- Dipendenze: SIP-025 (menu), SIP-020 (associazione e quote), SIP-021 C4,
  SIP-023 (ruoli e scope).

## Contesto

Richiesta dell'utente: la dashboard, invece dei contatori, deve essere più
accattivante e mostrare grafici.

Situazione verificata:

- `views/site/index.php`: quattro riquadri con un numero (aziende, negozi, POS,
  transazioni), filtrati con `User::can(40)`. "Transazioni" e "POS" fanno
  riferimento a dati che nella v2 non esistono più nella forma legacy.
- `SiteController::actionIndex`: solo codice commentato del vecchio sistema.
- Nessuna libreria di grafici nel progetto, né in Aura.

## Proposta

### Contenuti per ruolo

Admin:
- **Associazione**
  - soci attivi per anno, PF e PG (barre affiancate, ultimi 5 anni);
  - quote incassate per anno e metodo (barre impilate: contanti, PayPal,
    Bitcoin);
  - stato quote dell'anno in corso (anello: pagate, in attesa, scadute).
- **Esercenti:** negozi e terminali abilitati/disabilitati; operatori POS
  abilitati; inviti in attesa.
- **Sicurezza e attività:** eventi del registro negli ultimi 30 giorni per
  tipo (linea: attività, dati, sicurezza) e accessi POS rifiutati.

Gestore merchant (solo il proprio merchant, scope C4): negozi, terminali e
operatori abilitati/disabilitati; inviti in attesa.

Socio: stato della propria quota e storico dei propri pagamenti.

Ogni grafico ha un titolo, il totale in evidenza e una tabella o un testo
equivalente per chi non vede il grafico. Con dati assenti, messaggio "nessun
dato", non un grafico vuoto.

### Dati

- Aggregazioni calcolate sul server (un componente per la dashboard), con lo
  scope applicato **prima** dell'aggregazione, come negli elenchi C4.
- Solo conteggi e importi aggregati: nessun nome, email o identificativo nei
  dati del grafico.
- Periodi limitati (5 anni, 30 giorni) e query su colonne indicizzate.
- Dati passati alla pagina come JSON in un attributo `data-*`, codificato;
  nessuno script inline.

### Libreria

- Proposta: ApexCharts, la libreria usata negli esempi Tabler. Alternativa:
  Chart.js.
- Versione fissata, copiata in `web/bundles/charts/` con licenza e hash
  registrati (come `web/bundles/tabler/VERSION.md`); nessun CDN.
- Caricata con un AssetBundle solo nella dashboard; JS in
  `web/bundles/site/` (regola del progetto: niente JS nelle viste).
- Colori coerenti tra grafici e leggibili in tema chiaro e scuro; palette
  unica definita una volta.

## Criteri di accettazione

- Admin, gestore e socio vedono solo i grafici previsti, con dati del proprio
  scope; un gestore non vede dati di altri merchant neppure nei totali.
- Nessun dato personale nel JSON dei grafici; nessuno script inline.
- Dashboard leggibile da mobile; grafici con alternativa testuale.
- Dati vuoti gestiti; nessun errore con DB appena installato.
- Tempo di risposta della dashboard non peggiore di quello attuale in modo
  percepibile (query aggregate misurate sui dati di test).
- Test: aggregazioni e scope per ruolo su DB usa-e-getta; HTML senza PII;
  sintassi JS.

## Impatto

- `controllers/SiteController.php` (azione index), `views/site/index.php`,
  nuovo componente di aggregazione, nuovo AssetBundle e bundle JS/CSS.
- Libreria esterna nuova: richiede verifica licenza, versione e
  vulnerabilità prima dell'inclusione.

## Note implementative

- `SiteController` è oggi riservato al master (R3a): implementazione da
  assegnare dopo R3a.
- Grafici dei pagamenti dei merchant (POS/BTCPay) solo quando esisterà il
  relativo SIP di pagamento; "Transazioni" non ha oggi dati v2.
- Da fare dopo SIP-025, così la dashboard resta la pagina "Panoramica".

## Decisione master e ordine

Implementazione master dopo R3c e SIP-025. Prima contratto delle metriche e
verifica dati effettivamente disponibili: non inventare date di iscrizione,
attivita POS, importi o incassi merchant dai contatori legacy. Scelta libreria,
versione/licenza e vulnerabilita restano da verificare prima di aggiungerla;
questa conferma del numero non approva una nuova dipendenza. L'agente C4/B0
prosegue fase2 senza attendere dashboard o file UI del master.
