# SIP-022 B0 - Esiti delle verifiche

- Autore: agente Napay. Branch orchestratore `feature/btcpay-regtest-b0`.
- Riferimenti: [proposta](B0-PROPOSTA.md), [review master](B0-REVIEW-MASTER.md),
  [handoff](B0-HANDOFF.md).
- Nessuna chiamata alla produzione; nessuna chiave, password o dump qui.

## Fase 1 - Stack regtest (2026-11-12)

### Immagini verificate (punto 1 della review)

Tag verificati sul registry e fissati per digest; nessun `latest`.

| Immagine | Digest |
| --- | --- |
| `btcpayserver/btcpayserver:2.4.7` | `sha256:313b6178d8566784b8ec1811b80836df9157b9ee821098785bb0853ed1ef9df0` |
| `nicolasdorier/nbxplorer:2.6.21` | `sha256:117b061886f7b1f0a9ebdb0792c0195c77abda855b76dd51b0481bb4cae3fdc3` |
| `btcpayserver/bitcoin:32.1` | `sha256:71d1fd5a89dde910094c2f0532366ccbfa380c0684347465580204ca312f6bec` |
| `postgres:18.6` | `sha256:e3d24f6906d0760bf4da0dae872415391ededefad23fd471c47dc53b0ddf3c42` |

I tag coincidono con l'inventario dichiarato della produzione; la produzione
non è stata interrogata (review, punto 1).

### Esiti dopo la review di integrazione (B0-RV1..RV4)

- `tests/filesystem.sh`: **27 PASS** senza Docker reale (percorsi, symlink,
  file privati, reti omonime incompatibili; sentinelle intatte).
- `tests/isolated.sh`: **14 PASS** sullo stack reale con progetto, rete e
  stato temporanei:
  - servizi sani dopo 101 blocchi; nessuna porta host; digest; 0700/0600;
  - health `synchronized: true` dalla rete edge;
  - **OpenAPI non pubblica** (401 senza credenziali): si scarica in fase 2;
  - reti di ogni servizio verificate (solo interne; btcpayserver anche edge);
  - sentinella su bridge normale raggiunta da lì, irraggiungibile dalle reti
    regtest ed edge;
  - RPC del nodo: 401 dalla rete regtest (POST), connessione impossibile dalla
    edge sullo stesso IP; per nome non risolto;
  - stop/up conserva la chain; reset solo con `--yes` e solo sul progetto.
- `tests/topology.sh`: **11 PASS** sulla topologia proposta per l'integrazione
  (reti edge e client separate, proxy solo sulla client, blocco del backend
  nel gateway), solo controfigure locali.

## Fase 2 - Verifiche sul comportamento reale (2026-11-12)

Autorizzazione master: istanza regtest **usa-e-getta**, HTTP diretto sulla
rete interna del test. Il trasporto applicativo (proxy + TLS, punto 9) resta
quello verificato dal master sullo stack persistente. Script
`docker/btcpay-regtest/tests/phase2.sh`: **22 PASS**, nessun segreto nel log,
nessuna risorsa residua.

### Matrice

| # | Verifica | Esito |
| --- | --- | --- |
| 1 | Versione e OpenAPI | 2.4.7 (immagine fissata); OpenAPI v1 scaricata con l'admin di test: 138 percorsi, sha256 `9a7cc600a68aa88e...`. Senza credenziali 401. |
| 2 | Policy server | Il primo admin si crea senza autenticazione solo su istanza vuota (201). Poi la creazione anonima è rifiutata (401). Nessun server email: nessun invio possibile. |
| 3 | Utente con password casuale | 201, `requiresEmailConfirmation: false`, `requiresApproval: false`, `approved: false`, nessun ruolo. Stessa email di nuovo: 422 (nessun duplicato). |
| 4 | Permessi minimi | vedi "Permessi" sotto. |
| 5 | Proprietà e isolamento | P3: ogni merchant è unico Owner del proprio store; la sua chiave vede solo il proprio store, l'altro dà 403. |
| 6 | App POS | Creazione con la chiave del merchant (200, `PointOfSale`); elenco app dello store per riconciliazione (200). |
| 7 | Riconciliazione | Utente per email tecnica: 200. Store: nomi uguali accettati due volte, quindi il nome non è una chiave univoca: ricerca per nome = ambigua, serve mapping locale. |
| 8 | Errori | Chiave sconosciuta 401; chiave revocata dal titolare 401; permesso mancante 403 con `missing-permission`; store inesistente 403 (come uno altrui); servizio spento = nessuna risposta HTTP; **creazione utenti limitata: 429 con `Retry-After: 10`** (6 risposte 429 in una esecuzione, superate rispettando l'attesa). |
| 9 | Trasporto | fuori da questo script: verificato dal master sullo stack persistente (proxy, TLS, CA). |

### Permessi

| Operazione | Dichiarato nell'OpenAPI | Comportamento reale |
| --- | --- | --- |
| Creare utente | `btcpay.server.cancreateuser` | come dichiarato |
| Leggere utente per email | `btcpay.server.canviewusers` | come dichiarato |
| Creare store | `btcpay.store.canmodifystoresettings` | come dichiarato; lo store appartiene all'utente della chiave |
| Aggiungere utente a uno store | `btcpay.store.canmodifystoresettings` | **crea un invito** (il merchant non diventa membro); l'aggiunta diretta (`requireInvitation: false`) richiede **`btcpay.server.canmodifyserversettings`** |
| Creare app POS | `btcpay.store.canmodifystoresettings` | come dichiarato |
| Chiave per un altro utente | `btcpay.server.canmanageusers` | **richiede `btcpay.server.canmodifyserversettings`** (non documentato); `canmanageusers` non crea chiavi per l'admin (403) |
| Chiave propria (Basic) | `unrestricted` (cioè il titolare) | un utente normale si crea una chiave limitata ai propri store |

### Rotazione della chiave merchant (decisione B, 2026-11-13)

`phase2.sh` esteso (**30 PASS**, istanza usa-e-getta, nessun segreto stampato):

| Passo | Esito |
| --- | --- |
| R1 | Con la password tecnica (Basic) il merchant crea una seconda chiave limitata a `canmodifystoresettings`. |
| R2 | La nuova chiave vede esattamente gli stessi store e le stesse app POS; store di altri merchant 403. |
| R3 | La vecchia chiave resta valida finché non viene revocata. |
| R4 | Revoca esplicita (`DELETE /api/v1/api-keys/current` con la vecchia chiave): vecchia 401, nuova 200. |
| — | La nuova chiave non crea altre chiavi (403). |

Chiavi orfane (crash dopo la creazione e prima del salvataggio):
- l'OpenAPI 2.4.7 **non ha un endpoint per elencare** le proprie chiavi;
  `GET /api/v1/api-keys` con Basic non risponde 200;
- `DELETE /api/v1/api-keys/{apiKeyId}` con Basic e il valore della chiave
  risponde **400 `apikey-not-found`** e la chiave **resta valida**;
- l'unica revoca che funziona è `DELETE /api/v1/api-keys/current` con la
  chiave stessa: una chiave orfana (valore perso) si rimuove solo
  dall'interfaccia admin di BTCPay. Il limite di generazioni resta necessario.

### Conseguenza per la decisione B0-2 (da decidere)

Il modello P1 approvato ("una chiave provisioner, store del provisioner,
merchant aggiunto come Owner") **non funziona senza inviti** se la chiave non
ha `btcpay.server.canmodifyserversettings`, un permesso che consente di
cambiare le impostazioni dell'intero server. Alternative verificate:

| Opzione | Chiavi conservate | Permessi | Note |
| --- | --- | --- | --- |
| **P1 + server settings** | 1 (provisioner) | `cancreateuser`, `canviewusers`, `canmodifystoresettings`, **`canmodifyserversettings`** | Una chiave sola ma molto potente; il provisioner resta membro di tutti gli store. |
| **P3 (consigliata dall'agente)** | 1 provisioner + 1 per merchant | provisioner: solo `cancreateuser`, `canviewusers`; merchant: solo `canmodifystoresettings` sui propri store | Password casuale usata una volta per creare la chiave del merchant, poi scartata. Nessun permesso di server per gli store; danni limitati al singolo merchant. Le chiavi dei merchant vanno cifrate e revocabili. |
| Invito | 1 | senza server settings | Escluso: richiede che il merchant accetti un invito su BTCPay. |

Decisione richiesta all'utente (cambia B0-2) e al master (contratto B1).

## Fase 2 - Matrice iniziale (superata dalla sezione sopra)

Da eseguire tramite proxy di uscita su `https://btcpay.local`, CA verificata.
Matrice da compilare:

| # | Verifica | Esito |
| --- | --- | --- |
| 1 | Versione e OpenAPI scaricata con admin di test (hash registrato) | da fare |
| 2 | Policy server: registrazione, conferma email, approvazione utenti, store da non-admin, email server | da fare |
| 3 | Utente creato con password casuale, senza invito email: confermato, approvato, nessuna email | da fare |
| 4 | Permessi minimi provisioner: operazione -> permesso -> esito, niente `unrestricted` | da fare |
| 5 | Due merchant, due store: isolamento, ruolo proprietario, provisioner membro | da fare |
| 6 | App POS sullo store mappato e lettura per riconciliazione | da fare |
| 7 | Timeout simulato: ricerca per email tecnica/nome, risultati multipli = ambiguo | da fare |
| 8 | Errori: chiave errata/revocata, permesso mancante, servizio spento, 404, 429 | da fare |
| 9 | Trasporto: solo via proxy, TLS verificato, nessun redirect seguito | da fare |
