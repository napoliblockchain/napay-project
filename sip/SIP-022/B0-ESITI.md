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

### Esiti `tests/isolated.sh`: 11 PASS

- I quattro servizi partono sani; NBXplorer e nodo sincronizzati dopo 101
  blocchi minati al primo avvio (regtest parte in download iniziale).
- Nessuna porta pubblicata; tutte le immagini con digest.
- Cartella privata 0700, `regtest.env` 0600, `.gitignore` locale.
- `GET /api/v1/health` dalla rete edge: `synchronized: true`.
- **OpenAPI non pubblica:** `/swagger/v1/swagger.json` risponde 401 senza
  credenziali. Si scarica nella fase 2 con l'utente admin di test.
- Nessun container raggiunge internet; RPC del nodo non raggiungibile
  dalla rete edge.
- Stop/up conserva la chain senza minare di nuovo; reset rifiutato senza
  `--yes`, con `--yes` rimuove solo i volumi del progetto di test.

## Fase 2 - Verifiche via TLS (dopo integrazione del master)

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
