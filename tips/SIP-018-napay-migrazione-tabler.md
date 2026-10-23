# SIP-018 - Napay: migrazione AdminLTE a Tabler

- Stato: IN_PROGRESS (pilota layout e dashboard verificato; migrazione completa aperta)
- Area: Backoffice / UI / Accessibilita
- Repo: `napay`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-10-23
- Riferimento: `/var/www/levitas/aura/docs/sip/SIP-058-tema-tabler-switch-chiaro-scuro.md`

## Contesto

Napay usa Yii2 e Bootstrap 5 in `assets/AppAsset.php` e nei form, ma
`views/layouts/main.php` registra anche AdminLTE 3. Il layout applica `dark-mode`
fisso e legge il cookie `collapsed`. Il grafo asset effettivo va verificato prima
di rimuovere librerie: riferimenti Bootstrap 4 in commenti non provano un utilizzo
runtime.

Il `pathMap` in `config/web.php` punta a `themes/adminlte`, directory assente
nell'albero attuale; le viste disponibili sono sotto `views/`. Il primo passo e
verificare quali viste Yii risolve realmente, senza creare una seconda copia del
tema o replicare direttamente il pathMap di Aura.

Aura ha completato un passaggio analogo con `TablerAsset`, mapping degli asset
Bootstrap tramite il tema Yii, componenti menu e inizializzazione chiaro/scuro.
Questi sono riferimenti tecnici; branding e regole business restano Napay.

## Proposta

Adottare Tabler mantenendo navigazione, permessi, route, campi, validazioni,
azioni e flussi di pagamento. Nessuna modifica a merchant, negozi, POS, invoice,
BTCPay/API v1, crittografia o dati salvati dovuta al cambio tema.

1. Inventariare grafo asset e pagine raggiungibili, con baseline desktop/mobile.
2. Integrare asset Tabler locali e versione fissata, mantenendo licenza. Baseline
   di confronto: Aura usa Tabler 1.6.1 con CSS locale e Bootstrap JS 5.3.8.
   Confermare compatibilita nel lock Napay prima di adottare la stessa coppia.
3. Migrare layout, navbar, sidebar, contenuto e footer con un pilota dashboard
   e form merchant/POS. Conservare dati del menu e condizioni `User::is*`.
4. Adeguare griglie, widget Yii/Kartik, modali e form; poi login, profilo,
   amministrazione, documentazione Swagger e stati vuoti/errore.
5. Integrare comando chiaro/scuro secondo Aura, solo dopo baseline asset stabile:
   preferenza locale validata `light`/`dark`, applicata prima del rendering,
   funzionamento senza storage, cambio senza perdita dei form compilati.
6. Rimuovere AdminLTE e dipendenze obsolete solo dopo test di tutti i consumatori.

## Criteri di accettazione

- Una sola implementazione Bootstrap CSS/JS nelle pagine migrate; niente caricamento
  concorrente di Tabler JS completo e BootstrapPluginAsset.
- Route, ordine menu, visibilita per amministratore/merchant/user e selezione attiva
  invariati. Rendering aggiornato senza spostare autorizzazioni sul solo client.
- Form e widget conservano nomi campi, ID, eventi AJAX, CSRF e messaggi di errore.
- Login, logout, reset password, CRUD merchant/negozi/POS, invoice e chiamate API
  verificati con dati di test. Nessun pagamento reale nei test UI.
- Switch chiaro/scuro accessibile con tastiera, contrasto/focus leggibili e nessun
  reload o perdita dello stato della pagina. Gestione sicura del cookie legacy
  `collapsed`, senza interpolazione libera di classi o HTML.
- Layout verificato a 375, 768 e 1440 px: sidebar utilizzabile, nessun overflow
  pagina; scroll confinato alle griglie ampie.
- Export PDF/Excel conserva dati, formule e impaginazione; tema browser non entra
  negli export. Nessun cambiamento al service worker che memorizzi pagine private.
- Suite applicative e verifiche browser delle route interessate passano. Problemi
  preesistenti documentati separatamente; nessun completamento dichiarato dal solo lint.

## Impatto

- `napay/config/web.php`: risoluzione tema e mapping asset.
- `napay/assets/AppAsset.php`: CSS attuali `site.css`, `adminlte.css`, `yiipager.css`.
- `napay/views/layouts/`: main, navbar, sidebar, content, footer, login,
  footer-login, control-sidebar, snackbar e swagger_layout.
- `napay/views/`: dashboard, merchants, stores, pos, invoices, users, privilegi,
  impostazioni e log; verificare per gruppi prima delle modifiche.
- `napay/composer.json` e futuro lock: rimozione AdminLTE soltanto alla fine.
- Nuovi asset locali Tabler e test dedicati; nessuna migrazione DB prevista.

## Note implementative

- Riferimenti riutilizzabili Aura: `assets/TablerAsset.php`,
  `themes/adminlte`, `widgets/TablerSidebarMenu.php`, configurazione tema in
  `config/web.php`, test del menu e SIP-058. Non copiare namespace, palette,
  etichette o scelte di navigazione Aura.
- Mantenere PHP 8.3.36 e configurazione `.env`; nessun ritorno a `secrets.php`.
- Prima della verifica funzionale completa e del rilascio servono dipendenze complete e `composer.lock` riproducibile:
  attualmente vendor Napay e parziale e `composer.lock` e ignorato.
- Il vecchio vincolo PHPUnit 9.5 e la risoluzione dev segnalata in TIP-003 vanno
  risolti in intervento dedicato, senza disattivare controlli advisory Composer.
- Il rollout avviene per passi revisionabili; evitare sostituzioni globali di
  classi CSS o riscrittura integrale dei controller per ragioni estetiche.

## Verifica repository

Analisi iniziale: controllati `assets/AppAsset.php`, `views/layouts/main.php`,
`views/layouts/sidebar.php`, `views/layouts/login.php`, `config/web.php` e
`composer.json`. Consultati SIP-058, `config/env.php` e `assets/TablerAsset.php`
di Aura. La successiva implementazione pilota e descritta nel log seguente.

## Log implementazione pilota (2026-10-23)

- Confermata risoluzione delle viste locali in `views/`; rimosso il pathMap verso
  il tema assente. `NapayTheme` intercetta beforeRender prima dei widget e sostituisce
  gli asset solo per layout applicativo main. Login e layout dedicati esclusi.
- Tabler 1.6.1 e Bootstrap JS 5.3.8 locali, con licenze e provenienza; nessun CDN
  per il pilota. CSS e JS originali riusati da Aura, hash registrati in VERSION.md.
  Niente JS completo Tabler e niente Bootstrap 4 nel grafo applicativo migrato.
- `BackofficeAsset` sostituisce AppAsset nelle pagine applicative: nessun CSS
  AdminLTE/Bootstrap 4. AppAsset e dipendenze Composer legacy restano per i
  consumatori non ancora migrati; non e una rimozione completa di AdminLTE.
- Sidebar, navbar, contenuto, footer e card dashboard adeguati. Stesse voci,
  ordine, URL e condizioni User::is*/User::can, verificati per admin/merchant/user.
  Logout resta POST con CSRF Yii. Nessuna modifica a controller o query business.
- Toggle chiaro/scuro, preferenza locale allowlisted, inizializzazione prima del
  body e fallback quando storage e bloccato. Form compilati conservati al cambio.
- Sidebar mobile Bootstrap collapse e riduzione desktop. Il controllo nel profilo
  usa lo stesso stato locale, senza vecchio handler AdminLTE e reload. Cookie
  legacy letti tramite Yii e accettati soltanto per il valore previsto.
- Logo preservato anche in dark, testi dinamici codificati, etichette accessibili
  italiane. Colori semantici per Select2 e DatePicker; export e service worker
  generato non modificati.

Verifiche eseguite:

- 35 controlli PHP/Yii reali su PHP 8.3.36, con SQLite in memoria e vendor Aura
  compatibile montato in sola lettura nel solo container di test.
- 26 controlli Chromium/Playwright: 375/768/1440 px, assenza overflow, menu mobile,
  sidebar ridotta, tema persistente, preferenze invalide/storage bloccato, form
  non perso, Select2, DatePicker e modale con singolo backdrop. Zero errori JS
  non gestiti nelle fixture. Schermate desktop/mobile e widget controllate.
- Suite precedente configurazione .env e lint PHP/JS rieseguiti; diff verificato.
- Test ripetibili e istruzioni in `napay/tests/ui/`. Le fixture sono CLI-only,
  non introducono route web e non contattano servizi di pagamento.

Ancora aperto:

- Ripristinare dipendenze Napay e produrre lock riproducibile senza disattivare
  advisory Composer. I test con vendor isolato non equivalgono a validare il
  vendor Napay attualmente incompleto.
- Smoke autenticazione/CRUD/API con il DB di test reale e flussi merchant/negozi,
  POS, invoice e profilo; verificare tutti i widget, non solo il form pilota.
- Migrare login/layout dedicati, verificare PDF/Excel e cache PWA di rilascio,
  poi eliminare definitivamente AdminLTE e le dipendenze Bootstrap residue.
- Nessun deploy, commit o modifica a poawallet eseguito in questo intervento.
