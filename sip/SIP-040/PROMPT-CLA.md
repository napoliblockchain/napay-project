# Incarico CLA - SIP-040 fase A (2026-11-26)

Leggi prima /var/www/documents/AGENTS_secure_development.md e
/var/www/documents/progetti/napoliblockchain/COORDINAMENTO-AGENTI.md.
Il piano approvato e sip/PIANO-COMPLETAMENTO-2026-11-26.md nel worktree
/var/www/blockchain-napoli/napay-worktrees/backup-offsite.

## Obiettivo

Implementare la parte tecnica Napay di SIP-040: pagine anonime privacy,
condizioni e cookie; versionamento dei documenti e tracciamento della versione
accettata. Nessuna invenzione o pubblicazione di testi legali non approvati.

## Isolamento e ownership

- Parti dall'HEAD attuale del repository napay, dopo git status/log e lettura
  delle istruzioni locali. Registra SHA iniziale nel coordinamento.
- Nuovo branch feature/v2-privacy-documents e worktree dedicato sotto
  /var/www/blockchain-napoli/napay-worktrees/. Mai cambiare branch nel checkout
  servito dalla sandbox o di rilascio.
- Riservati file Napay necessari: SiteController, SignupForm e consensi,
  controller/form/service/view nuovi per i documenti, menu/footer, traduzioni,
  migration additiva e test dedicati. Prima inventaria modelli/config esistenti.
- Timestamp migration riservato: m261126_120000, controlla assenza collisioni.
- COD lavora solo su backup nell'orchestratore, non modifica Napay.
- Non modificare orchestratore, wallet, POS, deploy, env reali, gateway o VPS.
  Allegati/handoff in docs/SIP-040-HANDOFF.md nel tuo worktree Napay;
  master integra i riferimenti nel SIP canonico.

## Ordine micro-step

1. Inventaria gdpr_* importati, UserConsensus, SignupForm, action pubbliche e
   gestione contenuti esistenti. Segnala decisioni architetturali mancanti.
2. Scrivi contratto minimo nel tuo handoff prima del codice: versioni immutabili,
   bozza/pubblicato, policy per contenuto assente e consenso, autorizzazioni.
   Riutilizza infrastruttura esistente. Mai fallback silenzioso a consenso
   verso documenti vuoti/non approvati. Se la soluzione cambia l'iscrizione
   esistente, fermati su quel punto e chiedi approvazione al master tramite file.
3. Implementa pagine pubbliche, amministrazione versioni e collegamenti.
   I valori legacy sono bozza, non prova di approvazione. Contenuti non fidati:
   encoding o sanitizzazione HTML con allowlist; mai HTML eseguibile arbitrario.
4. Collega consensi alla versione immutabile; definisci e testa cosa succede
   dopo pubblicazione nuova versione e su account legacy senza versione.
   Nessun consenso marketing obbligatorio o implicito.
5. Test HTTP/DB isolati: anonimo, socio, merchant, operatore, admin; CSRF,
   XSS, versioni storiche, concorrenti, documenti assenti, nuove accettazioni.
   Regressioni iscrizione/attivazione/login. Nessun DB condiviso.

## Limiti

SIP-039 (retention, cancellazione) fuori incarico. Nessuna policy legale
approvata implicitamente: testi finali e durate spettano all'associazione.
Wallet/POS fase successiva; segnala contratti necessari, non implementarli.
Non installare provider o nuove dipendenze senza motivazione e verifica.
Non committare, fare push/merge o rilasciare senza richiesta esplicita.

## Consegna

Aggiorna tua sezione del coordinamento: branch/base, file, test realmente
eseguiti, limiti e percorso handoff. Test falliti/non eseguiti espliciti.
Richiedi review a COD; non attendere nuova richiesta dell'utente per segnalarla.
