# SIP-042 - Quote coerenti e merchant developer persona fisica

- Stato: OPEN; perimetro funzionale confermato il 2026-11-26, disegno tecnico
  proposto da finalizzare prima del codice.
- Area: Associazione / Quote / Identita / Merchant / POS.
- Repo: napay; orchestratore per documentazione; POS solo se il contratto cambia.
- Branch documentale: feature/member-fees-developer, da origin/main.
- Dipendenze: SIP-020/023/030/033/036; coordinamento con SIP-039/040/041.

## Contesto e origine della discrepanza

Segnalazione utente: account personale trasformato da PF a PG per provare le
funzioni merchant; pagamento quota propone 50 EUR, mentre Quote mostra annuale
20 EUR, Donazione 0 ed Esente 0. L'utente e realmente PF, non una societa.

Analisi statica di napay/components/association/MembershipFee.php:
- quota annuale scelta come prima membership_fees con duration >= 1, ordinata per id;
- importo online: precedenza a settings.quota_iscrizione_socio per PF e
  settings.quota_iscrizione_socioGiuridico per PG; solo in assenza di valore
  valido usa membership_fees.amount;
- AssociationController::actionTables mostra invece membership_fees.amount.

Sono due fonti diverse. Il codice spiega la divergenza; il valore effettivo 50
nelle impostazioni del DB reale non e stato letto durante questa analisi.
Le impostazioni e le quote sono importate separatamente da LegacyImporter.
Se import legacy attivo, ensureWritable blocca correttamente le modifiche:
non rimuovere tale protezione per aggirare la divergenza.

## Decisioni utente

1. L'admin deve poter gestire gli importi effettivamente applicati alle quote.
2. Developer PF resta PF e paga tariffa PF, non tariffa PG ne esenzione automatica.
3. Developer PF deve poter attivare merchant/azienda applicativa, negozi, POS
   e relativi operatori senza trasformazione fittizia in persona giuridica.
4. Funzione ammessa anche in produzione, con pagamenti reali per dimostrazioni.
   Non e limitata a sandbox, non conferma pagamenti simulati e non azzera importi.

Questa e un'eccezione esplicita alla regola SIP-023 "solo PG merchant", limitata
al developer PF autorizzato. PF ordinario resta escluso dall'attivazione merchant.

## Proposta

### A - Unica fonte delle quote

- Unificare tariffe realmente usate e schermata di amministrazione: catalogo
  con annuale PF e annuale PG esplicite; evitare scelta implicita del primo id.
- Struttura proposta: tipo quota e applicabilita PF/PG separati da descrizione,
  importo e durata. Finalizzare schema/additivita dopo inventario dei riferimenti.
- Eliminare la precedenza nascosta delle due impostazioni legacy, dopo una
  riconciliazione che conservi entrambi i valori e chieda conferma in caso di
  disaccordo. Nessuna scelta silenziosa fra 20 e 50, nessuna sovrascrittura di massa.
- Donazione ed Esente rimangono casi distinti; una riga zero non deve diventare
  annuale gratuita o sostituire la tariffa developer. Incoerenza/mancanza tariffa
  blocca il checkout con errore controllato, non applica un prezzo arbitrario.
- Schermata Quote mostra tariffa PF/PG effettiva, scopo e durata. Solo admin
  puo modificare, con POST/CSRF, validazione e audit valore precedente/successivo.
- Calcolo importo server-side con rappresentazione decimale esatta o centesimi;
  nessun importo o classificazione proveniente dal browser e autorevole.
- Nuove tariffe valgono per nuove richieste: versamenti, ricevute e richieste
  gia create mantengono importo/stato originali. Un checkout aperto non cambia
  prezzo; eventuale annullamento e nuova emissione sono operazioni esplicite.

### B - Capacita developer separata dall'identita

- Flag/capacita developer sull'account: default disabilitato; assegnazione e
  revoca solo da amministratore piattaforma con conferma, motivo e audit.
  Non esposto come attributo scrivibile in signup, profilo, invito o API POS.
- Non e un nuovo amministratore o un ruolo che salta controlli. Non cambia
  is_corporate, consenso, stato approvazione, email verificata o quota.
- Predicato merchant: PG qualificata secondo SIP-023, oppure socio PF attivo,
  approvato e developer autorizzato. In entrambi i casi un solo merchant per
  gestore; piu negozi e POS come nel modello attuale. Nessun accesso ad altri tenant.
- Adeguare congiuntamente AccountEligibility::classify/qualifiedMerchant/
  merchantForManager/canActivateMerchant, MerchantActivation, scope backoffice,
  provisioning e controllo sessioni. Oggi PF con merchant diventa CONFLICT:
  un solo controllo nel menu non implementa questa eccezione.
- Gestore non usa il POS direttamente: crea/invita account operatori separati,
  con email distinte, grant espliciti e apertura esclusiva gia previsti.
- Revoca flag a PF con merchant: definire nel contratto sospensione delle
  capacita commerciali, blocco nuove richieste e revoca sessioni/aperture.
  Non cancellare merchant, storico o fondi; continuare riconciliazione dei
  pagamenti reali gia creati. PG valida mantiene le capacita ordinarie.

### C - Dati reali, non una societa inventata

"Azienda" e il profilo merchant applicativo: non trasforma PF in societa.
Nessuna P.IVA, ragione sociale o identita PG inventata per superare i validator.
Oggi Merchants richiede e valida vatNumber: eccezione identitaria da sola non
basta. Proposta da finalizzare: scenario merchant intestato al developer PF,
dati PF veritieri e P.IVA non obbligatoria per tale scenario applicativo,
senza cambiare validazioni dei merchant PG ordinari. Verificare nullable/default
schema, API BTCPay, ricevute e template prima di introdurre la modifica.

Il flag non certifica requisiti fiscali o amministrativi e non li esenta:
intestazione delle ricevute, modalita d'uso e dati applicabili sono da confermare
con l'associazione. Non marcare transazioni reali come test e non falsificare
esiti o documenti. Eventuali incompatibilita con campi/API richiesti vanno
segnalate, non aggirate con valori fittizi.

### D - Regolarizzazione account gia trasformato

Blocco ordinario PF/PG resta valido. Il caso segnalato richiede procedura
specifica, autorizzata e auditata, per ripristinare la vera identita PF dopo
l'implementazione coerente dell'eccezione developer. Non aprire conversioni
generiche o aggiornare automaticamente tutti i merchant PF/PG.

Prima inventariare singolo account, merchant, negozi, terminali, sessioni e
pagamenti; non identificare il caso per email hardcoded nel codice. Conservare
legami, credenziali e storico. Una quota gia versata resta immutabile; una
richiesta in attesa da 50 EUR richiede riconciliazione esplicita, non ricalcolo
retroattivo o creazione automatica di un secondo pagamento.

## Criteri di accettazione

- Tariffa mostrata dall'admin coincide con checkout e richiesta inviata a provider.
- PF ordinario paga PF e non crea merchant; PG ordinaria paga PG e mantiene flusso.
- Developer PF paga PF, attiva un solo merchant e crea negozi/POS anche in prod.
- Nessuna esenzione automatica o conferma simulata: BTCPay/PayPal/TTS mantengono
  verifiche, importi server-side, TLS, idempotenza e stati reali.
- Non-admin non assegna flag o tariffe, anche tramite POST alterato o deep link.
- Developer non vede tenant altrui, non diventa admin e non incassa con account gestore.
- Revoca, login e apertura concorrenti verificati; storico e callback in corso preservati.
- Migrazione/import ripetuti non sovrascrivono tariffe amministrate ne abilitano developer.
- Donazione/Esente non selezionate per errore come annuale; zero gestito esplicitamente.
- Rettifica account richiede autorizzazione separata; nessuna modifica dati implicita.
- Test di regressione quote/manuale/PayPal/BTC, identita, provisioning, operatori,
  scope e SQL grants su stack usa-e-getta. Pagamenti reali di collaudo solo dopo
  autorizzazione specifica, non avviati dal codice o dalla migration.

## Impatto

MembershipFee, MembershipFees/Settings, AssociationController e viste Quote;
AccountEligibility, MerchantActivation, Merchants/form e scope; migration
additive, import compatibile, audit e test. Non modificare registrazione/consensi
in parallelo a CLA senza handoff. Primo micro-step possibile: riconciliare e
unificare le quote, poi capability developer e regolarizzazione del singolo caso.

## Note implementative

SIP prima del codice. Definire schema tariffe, dati merchant PF, revoca e piano
migrazione prima dell'implementazione. Nessun permesso developer assegnato,
nessuna quota/preferenza o identita modificata con questo documento.

## Verifica repository

Analisi statica 2026-11-26: MembershipFee.php, MembershipFees.php,
AssociationController::actionTables/ensureWritable, LegacyImporter,
AccountEligibility, MerchantActivation e regole Merchants. Nessuna lettura del
DB personale, nessun test funzionale, invio o pagamento reale eseguito.
