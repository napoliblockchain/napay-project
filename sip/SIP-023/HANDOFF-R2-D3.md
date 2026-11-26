# Handoff master - Dipendenze C4 R2 e login D3

Data: 2026-11-12. Leggere prima delle successive modifiche C4.

## Commit da integrare nel worktree C4

Nel repository Napay, cherry-pick in ordine:

1. `121fe3a2`: unicita email normalizzata R2, helper/lookup/signup/recovery,
   migration `m261112_135000`, test compatibili col vincolo.
2. `6487abbd`: login solo operatore R1, creazione sessione serializzata,
   controllo bearer R1, fixture/test nuovi.

Sono dipendenze del master, non modificare i file introdotti o aggiornati.
Segnalare conflitti al master; non risolverli cambiando policy/API o indebolendo
fixture per recuperare i vecchi login admin. Snackbar gia integrato separatamente.

## Correzioni C4 ancora necessarie

Resta valida [review C4](../SIP-021/C4-REVIEW-MASTER.md), salvo dipendenza email
ora consegnata. Risolvere snapshot obsoleto e revoca D3 sulle proprie classi.
Protocollo: merchant -> profilo operatore -> eventuale utente -> sessioni.
Login master usa READ COMMITTED per la sola transazione e mantiene lock fino
al commit. Disable C4 deve leggere/revocare anche sessioni committate prima
che acquisisca il lock, senza recuperare un vecchio snapshot.

Dopo i fix, rieseguire i runner C4, R2, eligibility API e catalogo su DB isolato;
aggiungere test C4+API in due processi per entrambi gli ordini della gara.
I 119 test master verificano il protocollo SQL, non attestano gia la fix C4.
Consegna commit piccoli + handoff, nessun merge sul branch di integrazione.

## Parte D - Gate email rimosso, via libera condizionato

Il master autorizza implementazione D e migration additiva riservata
`m261112_140000_create_pos_operator_invitations.php` soltanto nella worktree
e nei DB usa-e-getta, dopo avere aggiornato C4-BACKOFFICE con queste condizioni:

- Riutilizzare `EmailIdentity` e vincolo R2. Gestire violazione UNIQUE concorrente
  con rollback completo, nessun consumo invito o account duplicato; errore generico.
- Accettazione: lookup token come hint, lock merchant PRIMA del lock invito,
  quindi rileggere token/digest, merchant, stato e scadenza. Evitare ordine inverso
  rispetto a emissione/reinvio/annullamento; mantenere ordine comune dei writer.
- Profilo operatore esplicito e disabilitato, nessun grant; base attivo,
  is_merchant=0, niente profilo/quote associativi. Mai SignupForm::signup,
  scelta ruolo dal POST, logica primo-admin, reset o riuso di account esistente.
- Mail su file, token solo digest nel DB e niente token/password nei log/risposte
  merchant. Rate limit anche su avvisi per indirizzi gia registrati, per evitare spam.
- Distinzione accesso portale associativo/operatori e registrazione PF/PG resta
  R3 del master: non dichiarare SIP-023 concluso per la sola consegna degli inviti.

Nessun DDL sulla sandbox condivisa e nessuna attivazione/seed di operatori reali.
A-C devono comunque superare review prima dell'integrazione. Ordine operativo
B0 invariato: preparazione stack gia assegnata, su file/branch propri; nessuna
modifica diretta a gateway/egress/launcher o provisioning B1.

## Esiti master e limiti

R2 106 schema + 14 app; policy 24; reset 68; attivazione 92; C1/login/logout
51/62/32; catalogo 177; API/protocollo D3 119; runtime completa con restart/no-op.
Tutti eseguiti su stack usa-e-getta. Nessuna prova browser del nuovo operatore,
nessun pagamento, apertura, sblocco, provisioning BTCPay o migration condivisa.
