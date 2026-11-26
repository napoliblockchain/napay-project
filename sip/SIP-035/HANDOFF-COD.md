# SIP-035 - Handoff COD

**PRONTO PER REVIEW**, 2026-11-19. Integra solo il master CLA; nessun push,
merge/cherry-pick in main, deploy o migration condivisa eseguiti da COD.

## Branch E Commit

| Repo | Worktree | Branch / base | Commit nell'ordine |
| --- | --- | --- | --- |
| napay | `/var/www/blockchain-napoli/napay-worktrees/napay-password` | `feature/v2-password-change`, base `593b2382` | `22c8ba77`, `a65b9eed`, `177c16aa` |
| poawallet | `/var/www/blockchain-napoli/napay-worktrees/poawallet-password` | `feature/v2-password-change`, base `0272ccb` | `bc7059b`, `0828e6e` |

Entrambe le worktree pulite. Commit effettuati con `git commit --only` dei
soli file assegnati. Questo handoff resta non committato nell'orchestratore.

## Implementazione

- Entrambe le app: GET `/users/change-password` mostra form; solo POST con
  CSRF modifica. Identita dal server, mai da ID nel form. Password attuale,
  nuova, conferma; minimo dal parametro esistente, massimo72 byte bcrypt
  (anche UTF8), nessun trim della password, array rifiutati senza500.
- Riga utente bloccata e riletta: account attivo e authKey ancora uguale
  all'identita autenticata. Hash con `Users::setPassword` corrente,
  rotazione authKey/accessToken e rimozione del reset pendente nella stessa
  transazione; log attivita. Logout corrente; altre sessioni e ricordami
  respinti dal controllo authKey gia presente in Yii, senza nuovi campi.
- Napay: sessioni POS non revocate lette con lock, poi `PosApi::revoke`
  invariato, motivo password_changed, nella stessa transazione. Nessuno
  sblocco implicito delle aperture.
- Limiti riusando Throttle invariato:5 tentativi/900s per account,
  20/900s per IP. Risposta429 con Retry-After, messaggio generico.
- Notifica email HTML+testo dopo commit, senza password o altri segreti.
- Napay admin: POST `/users/send-password-reset?id=...`, ID cifrato della
  sessione e controllo record-level esistente. Riusa PasswordResetRequestForm,
  non imposta password. Risposta neutra e audit. Pulsante mai sul proprio
  account; anche chiamata diretta admin sul proprio ID negata403.
- Wallet: nessuna lettura/modifica di seed o chiavi; dati mp_wallets invariati.
  Usa WalletForm esistente, non un form parallelo. FileTarget della SOLA nuova
  rotta con logVars vuote e traceLevel0 prima dei filtri, inclusi errori CSRF.

## Ownership E Approvazioni

Recepite risposte CLA nel coordinamento:
- Napay `_details-edit.php`: aggiunta SOLO una riga di render del nuovo
  `_password-reset.php`, protetto admin/non-proprio anche nel partial.
- Wallet `components/Throttle.php`: copia byte-identica del file Napay,
  tranne commento d'origine; confronto diff eseguito. Nessuna modifica al
  Throttle di Napay. FileMutex creato solo nella nuova rotta se manca.
- Nuovo `mail/layouts/text.php` wallet: mancava il layout testo predefinito
  di Yii, necessario per la mail multipart; nessun layout esistente cambiato.
- Nessuna modifica a Users/Stores/Merchants, PosApi, DatabaseRoles, migration,
  configurazione globale, layout principale, compose o launcher.

## File Napay

`controllers/UsersController.php`, `models/forms/ChangePasswordForm.php`,
`views/users/{change-password,_password-reset,_details-edit}.php`,
`views/layouts/navbar.php`, `messages/it-IT/app.php`,
`mail/{passwordChanged,passwordChanged-text}.php`,
`tests/application/password-change.php`, `tests/docker/password-change.sh`.

## File Wallet

`components/Throttle.php`, `controllers/UsersController.php`,
`models/ChangePasswordForm.php`, `views/users/change-password.php`,
`views/layouts/_navbar.php`, `messages/it-IT/app.php`,
`mail/{passwordChanged,passwordChanged-text}.php`, `mail/layouts/text.php`,
`tests/password-change.php`, `tests/docker/password-change.sh`.

## Test Eseguiti

- Napay `tests/docker/password-change.sh`: **50 PASS**, HTTP + MySQL reale,
  file mail. Include pulsante admin, POST/CSRF, reset di altro account senza
  cambiare hash, rifiuto reset su se stesso, nonce/ID non validi, mass assignment,
  password errata, conferma, minimo,72 byte/UTF8, array, throttle, sessioni
  web/ricordami reali, revoca POS e assenza password da mail/log.
- Napay `tests/docker/runtime.sh`: runtime completa verde prima del follow-up
  UI; `tests/docker/roles-bootstrap.sh`: runtime completa finale con ruoli
  ristretti verde, compresi restart, persistenza DB e bootstrap no-op.
- Wallet `tests/docker/password-change.sh`: **38 PASS**, HTTP + MySQL vuoto
  usa-e-getta con vere migration esistenti, nessuna chain o rete esterna.
  Stessi negativi, sessioni/ricordami, mail senza password, log CSRF senza dump,
  account disabilitato e confronto integrale mp_wallets prima/dopo.
- Wallet regressioni senza rete, SQLite in memoria: `access-control.php`
  **173 PASS**, `ownership.php` **15 PASS**, `error-handler.php` **7 PASS**.
- PHP8.3.36 `php -l` su TUTTI i file PHP toccati (solo container), `sh -n`
  su runner e `git diff --check` dell'intero intervallo di commit: verdi.

Log locali di test: `/tmp/napay-sip035-password.log`,
`/tmp/napay-sip035-runtime.log`, `/tmp/napay-sip035-runtime-restricted.log`,
`/tmp/wallet-sip035-password.log`, `/tmp/wallet-sip035-security.log`.
Nessun log completo riversato in questo documento.

## Limiti E Rischi Residui

- Nessun test/deploy sulla sandbox condivisa, nessuna automazione browser;
  UI mobile/gestione chiavi lato browser e regressione chain wallet completa
  non collaudate in questo incarico. Nessun nuovo JS/CSS.
- Nel worktree wallet il vendor host era vecchio: allineato SOLO il vendor
  ignorato all'immagine `napay/poawallet:dev` gia presente. Nessun composer
  update o cambio lockfile/versioni; fixture e migration girano come uid33.
- Se SMTP fallisce dopo commit, password resta cambiata e sessioni revocate;
  warning fisso senza dati sensibili. Nessuna coda automatica di reinvio.
- Il SIP cita rehash trasparente al login: NON aggiunto ai modelli/login
  condivisi (fuori write set). Il cambio genera gia hash corrente. Eventuale
  rehash al solo login e allineamento globale vecchi signup/reset wallet
  (nuovo cambio max72 byte) restano da valutare/assegnare al master.
- Due fattori (punto6) esclusi come richiesto. Nessun cambio PHP.
