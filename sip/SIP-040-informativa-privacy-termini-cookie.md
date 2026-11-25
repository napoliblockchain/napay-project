# SIP-040 - Informativa privacy, condizioni di utilizzo e cookie

- Stato: OPEN
- Area: Privacy / GDPR / Legale
- Repo: `napay`, `poawallet`, `pos`
- Branch target: `feature/v2-*`
- Segnalato: 2026-11-25 (richiesta utente)

## Contesto
La registrazione a Napay chiede di accettare statuto, informativa sulla privacy e condizioni di
utilizzo. Lo statuto è un link al sito dell'associazione e funziona. I link all'informativa
(`site/print-privacy`) e alle condizioni (`site/term-of-use`) puntano a pagine che nella v2 non
esistono: l'utente accetta documenti che non può leggere. I dati della v1 per l'informativa sono
stati importati (impostazioni `gdpr_*`) ma non sono usati. Il wallet e il POS non hanno
informativa né condizioni. Manca una cookie policy.

Cookie oggi: Napay, wallet e POS usano cookie tecnici (sessione, CSRF, accesso), per i quali non
serve consenso (provvedimento del Garante privacy del 10 giugno 2021 sui cookie). Alcune pagine o
email caricano però risorse da terzi (per esempio Google Fonts nelle email del wallet), che
trasmettono l'IP del visitatore a quei servizi.

## Proposta
1. **Pagine pubbliche** in Napay, wallet e POS, raggiungibili senza login e dal piede di pagina:
   - Informativa privacy (art. 13 GDPR): titolare (Napoli Blockchain ETS), contatti, finalità,
     basi giuridiche, durate (dalla tabella di SIP-039), destinatari e responsabili esterni
     (hosting Contabo, BTCPay, PayPal, Brevo per l'invio delle email), trasferimenti fuori UE,
     diritti e modalità di esercizio, reclamo al Garante; per il wallet: dati sulla blockchain
     pubblici e immutabili, seed custodita solo dall'utente.
   - Condizioni di utilizzo: servizio dell'associazione ai soci, uso dei wallet e dei token TTS,
     responsabilità, sospensione e cessazione dell'account, legge applicabile.
   - Cookie policy: elenco dei cookie tecnici (nome, scopo, durata) e dei servizi di terzi.
2. **Testi gestiti dall'admin** (versionati), non scritti nel codice: modifica da backoffice,
   numero di versione e data; ogni consenso registrato con la versione accettata (oggi
   `user_consensus` registra solo il timestamp). Alla pubblicazione di una nuova versione delle
   condizioni, richiesta di nuova accettazione al primo accesso.
3. **Cookie e terze parti**: rimuovere o ospitare in locale le risorse di terzi (font, script,
   immagini) in pagine ed email, così da restare con soli cookie tecnici e **nessun banner**.
   Se in futuro servissero cookie di analisi o di profilazione: banner di consenso
   (Iubenda, Cookiebot o soluzione open source come Klaro), con blocco preventivo e scelta
   granulare, da decidere con una SIP dedicata.
4. Correzione dei link della registrazione verso le nuove pagine.

## Criteri di accettazione
- Le pagine esistono in Napay, wallet e POS, senza login, e i link della registrazione funzionano.
- I testi sono approvati dall'associazione e modificabili dall'admin con versione e data.
- Il consenso registra la versione accettata; una nuova versione delle condizioni chiede una
  nuova accettazione.
- Nessuna richiesta verso domini di terzi nelle pagine e nelle email (verificato con una scansione
  dei template e una prova nel browser), oppure banner di consenso se resta un servizio di terzi.

## Impatto
- Napay: pagine pubbliche, gestione testi nel backoffice, migration (versioni e consensi), link
  della registrazione, piè di pagina.
- Wallet e POS: pagine pubbliche (testi letti da Napay o propri), piè di pagina, template email.

## Note implementative
- I testi legali sono responsabilità dell'associazione: il software fornisce struttura, versioni
  e registrazione dei consensi; bozza dei testi da far verificare a un consulente privacy.
- Riusare i valori `gdpr_*` importati dalla v1 come punto di partenza.
- Coordinata con SIP-039 (durate) e SIP-038 (backup fuori macchina tra i responsabili esterni).
- Valutare Iubenda solo se servono cookie non tecnici: è un servizio a pagamento esterno e
  aggiungerebbe proprio una terza parte nelle pagine.

## Verifica repository
- Da compilare a lavoro concluso.
