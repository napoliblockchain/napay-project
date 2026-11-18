# SIP-035 - Gestione password di Napay e del wallet

- Stato: OPEN
- Area: Account e sicurezza
- Repo: `napay`, `poawallet`
- Branch target: `feature/v2-yii2-php83-docker`
- Segnalato: 2026-11-18

## Contesto
Napay e il wallet (poawallet) hanno solo il recupero della password via email
("password dimenticata", link a scadenza). Manca il cambio password da utente
collegato, in entrambe le applicazioni. Gli utenti importati dalla v1 entrano con
la password v1 (hash bcrypt conservato), che oggi non possono cambiare se non
passando dal recupero via email. Nella v1 3 utenti avevano anche l'accesso a due
fattori (Google Authenticator, `ga_secret_key`), che la v2 non importa.

## Proposta
1. Napay, profilo utente: "Cambia password" con password attuale, nuova e
   conferma; regole minime uguali alla registrazione; hash con l'algoritmo
   corrente (rehash trasparente degli hash v1 al primo accesso riuscito).
2. Dopo il cambio: chiusura delle altre sessioni e dei "ricordami" (rotazione
   di `authKey`), sessioni POS dell'operatore revocate, email di avviso al
   titolare dell'account (mai la password), registro attività.
3. Limite ai tentativi sulla password attuale (come il login), POST con CSRF.
4. Admin: nessuna impostazione diretta della password altrui; solo "invia
   link di reset" all'utente (stesso flusso del recupero), registrato nel log.
5. Wallet (poawallet): stessa funzione nel profilo, con le stesse regole; il
   cambio della password dell'account non tocca chiavi o seed del wallet (mai
   custoditi dal server).
6. Due fattori: da decidere a parte (import dei 3 segreti v1 o riattivazione
   da parte dell'utente), non in questo SIP.

## Criteri di accettazione
- Cambio possibile solo con la password attuale corretta; errori senza
  dettagli; limite ai tentativi.
- Dopo il cambio le altre sessioni (web, "ricordami", POS) non sono più valide.
- Email di avviso inviata; nessuna password in email, log o risposte.
- Admin può solo inviare il link di reset.
- Test su stack usa-e-getta per Napay e wallet.

## Impatto
- `napay`: profilo utente, modello/form, sessioni POS, mail, log, test.
- `poawallet`: profilo, form, sessioni, mail, test.

## Note implementative
- Riutilizzare le regole di validazione e il mailer già usati da registrazione
  e recupero password.
