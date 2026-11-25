# SIP-039 - GDPR: conservazione massima dei dati e cancellazione dell'account

- Stato: OPEN
- Area: Privacy / GDPR / Account
- Repo: `napay`, `poawallet`, `pos`, orchestratore
- Branch target: `feature/v2-*`
- Segnalato: 2026-11-25 (richiesta utente)

## Contesto
Oggi l'unica regola di conservazione automatica cancella gli account mai verificati dopo 7 giorni
(Napay). Non esistono: una durata massima per gli altri dati personali, una richiesta di
cancellazione dell'account da parte dell'interessato (art. 17 GDPR), un periodo di ripensamento.
L'admin può eliminare un socio solo se non ha quote, merchant o casse collegati. Il wallet ha
account separati (tabella `mp_users`) e nessuna cancellazione. Restano inoltre dati tecnici con
dati personali senza scadenza: registro attività (IP, browser), email salvate su file, backup.

## Proposta
1. **Inventario dei trattamenti** (tabella in questa SIP, da approvare con l'associazione,
   titolare del trattamento): per ogni dato la finalità, la base giuridica e la durata.
   Proposta iniziale da validare:
   | Dato | Durata proposta | Motivo |
   | --- | --- | --- |
   | Account mai verificato | 7 giorni (già attivo) | nessun rapporto instaurato |
   | Socio attivo: anagrafica, consensi | per tutta la durata dell'iscrizione | rapporto associativo |
   | Socio cessato o account cancellato | anagrafica anonimizzata dopo il periodo di ripensamento | art. 17 |
   | Quote pagate, ricevute, verbali | 10 anni (scritture contabili, libro soci ETS) | obbligo di legge, art. 17.3.b |
   | Incassi POS dei negozi | 10 anni, senza dati del cliente | obbligo contabile del merchant |
   | Registro attività (IP, browser) | 12 mesi | sicurezza |
   | Email salvate su file (Posta in uscita) | 30 giorni | solo ripiego tecnico |
   | Backup locali / fuori macchina | 14 giorni / 90 giorni (SIP-038) | ripristino |
2. **Richiesta di cancellazione dall'interessato**, in Napay e nel wallet, dal proprio profilo:
   conferma con password, account sospeso subito (niente accesso, niente email di marketing),
   **30 giorni di ripensamento** con annullamento possibile su richiesta (email all'admin o link
   nell'email di conferma), poi cancellazione o anonimizzazione automatica.
   - Napay: elimina anagrafica, consensi, profilo; dove la legge impone di conservare (quote,
     ricevute, libro soci), sostituisce i dati con un identificativo anonimo.
   - Merchant e operatori POS: prima va chiuso o trasferito il merchant (negozi, casse); la
     richiesta lo segnala e l'admin la completa.
   - Wallet: elimina account e dati locali; la seed resta solo all'utente. Le transazioni sulla
     chain sono immutabili e non contengono nomi: va scritto nell'informativa (SIP-040).
   - Email all'interessato: richiesta ricevuta, promemoria prima della scadenza, conferma finale.
3. **Pulizia periodica** (comandi una tantum nel cron, come `purge-unverified`): registro attività
   oltre 12 mesi, email su file oltre 30 giorni, richieste scadute, soci cessati oltre la durata.
4. **Diritti dell'interessato oltre alla cancellazione**: esportazione dei propri dati (art. 15 e
   20) in formato leggibile dal profilo; da valutare nello stesso intervento.
5. Registro delle cancellazioni (solo data, identificativo anonimo, esito) per dimostrare
   l'adempimento senza conservare i dati cancellati.

## Criteri di accettazione
- Durate approvate dall'associazione e scritte nell'informativa (SIP-040).
- Un utente può chiedere la cancellazione dal profilo; per 30 giorni può annullarla; dopo, i suoi
  dati personali non esistono più (verificato su database usa-e-getta), salvo i dati con obbligo
  di conservazione, anonimizzati.
- I comandi di pulizia sono idempotenti, girano nel cron e registrano solo conteggi.
- I backup scadono secondo la tabella; un dato cancellato sparisce dai backup entro la loro durata.
- Test per: richiesta, annullamento, scadenza, merchant con negozi attivi, dati contabili conservati.

## Impatto
- Napay: profilo (richiesta e annullamento), comandi del cron, migration per lo stato della
  richiesta, email, pagina admin delle richieste.
- Wallet: richiesta dal profilo, pulizia, email.
- POS: nessun dato personale dei clienti; operatori seguono l'account Napay.
- Orchestratore: retention dei backup (SIP-038).

## Note implementative
- Le durate e le basi giuridiche sono decisioni dell'associazione (titolare): questa SIP propone,
  non decide. Consigliata una verifica con un consulente privacy.
- Anonimizzare invece di cancellare dove servono totali e storico (quote, incassi).
- Dipendenze: SIP-020 (dati associazione), SIP-023 (profili), SIP-038 (backup), SIP-040
  (informativa).

## Verifica repository
- Da compilare a lavoro concluso.
