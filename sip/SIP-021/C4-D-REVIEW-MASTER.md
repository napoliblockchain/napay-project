# C4 parte D - Review master inviti operatore

Data: 2026-11-12. Commit esaminati: 63911cae, f25acc04, 5a6ef31b,
19b06f0b, con 450d395d equivalente a e0132f64. Nessuna integrazione D ancora
approvata. Test dichiarati dall'agente non rieseguiti dal master in questa review.

## Correzioni richieste

1. AcceptInvitationForm limita la password a72 caratteri, non72 byte.
   Bcrypt tronca oltre72 byte: applicare controllo byte come signup/reset,
   anche al confine del servizio accept, riusando validazione esistente.
   Provare UTF8 e suffissi oltre limite senza loggare password o hash.
2. Filtri first_name/last_name mantengono array: StringValidator rifiuta,
   ma activeTextInput puo produrre500. Normalizzare input non testuali a
   stringa vuota, poi required; test HTTP per entrambi i nomi senza consumo
   invito o creazione account.
3. deliver aggiorna esito solo per ID: consegna tardiva di generazione
   precedente puo alterare esito dopo resend. CAS anche su token_sha256.
   Costruzione URL/parametri mail dentro try: errore configurazione post-commit
   deve diventare invio fallito controllato, non500 diverso per email esistenti.
   Test generazione obsoleta e fallimento costruzione/invio mail.

Correzioni assegnate all'agente nel suo worktree C4. Il master non modifica
quei file; nuova review e test prima di cherry-pick. Nessuna modifica allo
schema C1 o alle decisioni identita/SIP-023 autorizzata implicitamente.
