# SIP-025 - Napay: menu per macroaree e amministrazione per sezioni

- Stato: OPEN - proposta dell'agente Napay su richiesta dell'utente (2026-11-12);
  numero da confermare dal master, che gestisce l'indice.
- Area: Backoffice / UI / Navigazione.
- Repo: `napay`; orchestratore per documentazione.
- Branch target: `feature/v2-yii2-php83-docker`.
- Segnalato: 2026-11-12.
- Dipendenze: SIP-018 (Tabler), SIP-023 R3c (portale soci/operatori e menu),
  SIP-021 C4 (Terminali POS).

## Contesto

Richiesta dell'utente: l'amministrazione deve essere un menu con sottomenu
che apre i singoli controller; la pagina globale "Pannello Admin" non serve.
Il menu va riorganizzato per macroaree.

Situazione verificata sul codice (`feature/v2-yii2-php83-docker`):

- `views/layouts/sidebar.php`: elenco piatto di 11 voci, nessun raggruppamento.
- `widgets/TablerSidebarMenu.php`: disegna solo voci semplici e intestazioni;
  le voci con `items` (sottomenu) non sono gestite.
- `AdminController::actionIndex` (`/admin/index`): una pagina che affianca 4
  griglie da 5 righe (utenti, privilegi, impostazioni, registro). Le stesse
  funzioni esistono già come controller dedicati con elenco, dettaglio e
  scritture: `UsersController`, `PrivilegesController`, `SettingsController`,
  `LogsController`.
- **Link rotti o incoerenti:**
  - "Pannello Admin" è visibile anche al gestore merchant, ma il controller
    richiede livello 40: il gestore ottiene 403.
  - "Transazioni" punta a `invoices/index`, ma nella v2 non esistono né il
    controller né la tabella: la voce porta a una pagina inesistente.
- "Paga quota" è visibile a tutti, compresi gestori e futuri operatori POS, che
  per SIP-023 non sono necessariamente soci.

## Proposta

### Macroaree

| Macroarea | Voci (sottomenu) | Chi la vede |
| --- | --- | --- |
| Panoramica | Dashboard | tutti gli utenti connessi |
| La mia area | Paga quota, Il mio profilo | soci (identità associativa coerente, R3c) |
| Associazione | Soci, Quote associative, Verbali, Tabelle associazione | admin |
| Esercenti | Aziende (admin), Negozi, Terminali POS | admin e gestore qualificato |
| Amministrazione | Utenti, Profili e privilegi, Impostazioni, Registro attività | admin |

- "Transazioni" esce dal menu finché non esiste la funzione (SIP pagamenti
  futuro); non si lasciano voci verso pagine inesistenti.
- Ogni macroarea è un gruppo comprimibile della barra laterale Tabler
  (`nav-item dropdown`), aperto automaticamente se contiene la pagina attiva.
  Macroarea con una sola voce visibile: voce diretta, senza gruppo.
- Le regole di visibilità usano gli stessi controlli dei controller
  (`User::isAdministrator`, `Scope::current()` per Esercenti, policy R3c per
  La mia area), non il solo livello numerico.

### Amministrazione per sezioni

- Le quattro voci aprono i controller dedicati già esistenti.
- `/admin/index` viene rimosso: per una versione reindirizza (302) a
  `users/index` per gli admin; per gli altri resta negato come oggi.
  Poi `AdminController` e `views/admin/*` si eliminano.
- Si verifica che ogni controller dedicato offra ciò che il pannello mostrava
  (ordinamento più recente per primo, pager unico LinkPager, filtri); dove
  manca si aggiunge nel controller dedicato, non in una nuova pagina globale.

### Widget menu

Estendere `TablerSidebarMenu` per i sottomenu: gruppo con titolo e icona,
elenco interno, stato attivo propagato al gruppo, attributi ARIA
(`aria-expanded`, `aria-controls`) e navigazione da tastiera. Nessun JS
nuovo oltre a quello di Tabler/Bootstrap già caricato.

## Criteri di accettazione

- Per ciascun ruolo (admin, gestore qualificato, gestore non qualificato,
  socio PF, socio PG, operatore POS, anonimo): il menu mostra solo le
  macroaree previste e **ogni link visibile risponde 200** per quel ruolo.
- Nessun link verso controller inesistenti o negati.
- `/admin/index` non mostra più la pagina aggregata; i controller dedicati
  restano protetti lato server (il menu è solo presentazione).
- Gruppo della pagina corrente aperto ed evidenziato; navigazione da tastiera
  e lettore di schermo funzionanti; layout mobile invariato.
- Nessuna regressione su login, associazione, C4, R3.

## Impatto

- `views/layouts/sidebar.php`, `widgets/TablerSidebarMenu.php` (file del
  master: layout/menu).
- `controllers/AdminController.php`, `views/admin/*` (rimozione).
- Eventuali piccoli adeguamenti a `Users/Privileges/Settings/LogsController`.
- Test: nuovo test HTTP del menu per ruolo; regressioni runtime.

## Note implementative

- Ownership: layout e menu sono del master (COORDINAMENTO.md). Implementazione
  da assegnare dal master; La mia area dipende da R3c (portale soci/operatori),
  da fare insieme o subito dopo.
- Solo modifica della navigazione: nessuna nuova autorizzazione, nessun dato.
- Il menu calcolato una volta per richiesta: `Scope::current()` e la policy
  fanno query, evitare chiamate ripetute per ogni voce.
