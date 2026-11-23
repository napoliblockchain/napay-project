# SIP-036 parte B - Incarico agente cod: POS v2 in produzione (2026-11-23)

Assegnato dal master (CLA). Leggi prima `sip/COORDINAMENTO.md`,
`sip/SIP-036-rilascio-v2-vps.md` e `/var/www/documents/AGENTS_secure_development.md`.
Rispondi in italiano. Domande e avanzamento nella tua sezione di
`/var/www/documents/progetti/napoliblockchain/COORDINAMENTO-AGENTI.md`.

## Dove lavori

| Repo | Worktree | Branch | Base |
| --- | --- | --- | --- |
| pos | `/var/www/blockchain-napoli/napay-worktrees/pos-deploy` | `feature/v2-pos-deploy` | `50b9b6d` |

Mai nella cartella `napay-project/pos` (montata dal master). Mai push, merge
o cherry-pick sul branch di integrazione: integra il master.

## Obiettivo

Il POS v2 (`v2/`) deve poter girare in produzione sulla VPS dietro il gateway
dell'orchestratore, collegato al Napay v2 reale.

1. **Modalità produzione nell'app.** Oggi `config/web.php` accetta solo
   `POS_MODE=preview`. Aggiungi `production` (valori ammessi solo questi due):
   - in produzione niente funzioni della chain di test: azione
     `payment/request` (404) e pulsante "Copy payment request (test chain)"
     nascosti;
   - `/health` riporta la modalità reale, senza dati interni;
   - proxy fidato (oggi `10.251.0.0/24` fisso) da variabile d'ambiente
     validata, con default invariato per la sandbox;
   - CA: in produzione il POS chiama Napay sulla rete Docker interna con la CA
     locale del gateway (`/var/www/documents/progetti/napoliblockchain/napay/architettura-produzione.md`),
     quindi `NAPAY_CA_FILE` resta supportata; se assente, verifica TLS con le
     CA di sistema (mai disattivata). URL API solo HTTPS.
2. **Composizione di produzione**: overlay o file dedicato in `v2/` con
   immagine versionata (tag dal commit, mai `:dev`), file env privato,
   chiave client come secret, runtime persistente in cartella privata,
   nessuna porta sull'host, rete del gateway da variabile, healthcheck,
   read-only come oggi.
3. **Script di rilascio** `v2/docker/deploy.sh env-file [--check]`, sul
   modello di `deploy-wallet.sh` dell'orchestratore (leggilo, non
   modificarlo): `--check` valida file env (0600, fuori dai repo, proprietario),
   variabili, secret e compose senza costruire né avviare; il rilascio
   costruisce l'immagine, avvia, aspetta l'healthcheck e, se fallisce,
   rimette in servizio l'immagine precedente.

## File

Tuoi: tutto sotto `v2/` nel tuo worktree (config, controller/view toccati per
la modalità, `docker/`, `docs/`, test, traduzioni con `Yii::t` sorgente
inglese + catalogo it). Non cambiare il comportamento di `docker/local.sh`
e della sandbox.

Del master (non toccare, proponi nell'handoff): gateway
(`docker/gateway/conf.d/pos.caddy`, domini reali), `docker/compose/*.yml`
dell'orchestratore, `deploy-wallet.sh`, Napay.

## Test

Solo risorse usa-e-getta con nomi univoci, nessuna sandbox condivisa,
nessuna VPS, nessun Internet. Copri almeno: `--check` con env assente,
permessi larghi, symlink, dentro il repo, variabili mancanti o non valide;
modalità non ammessa rifiutata; in produzione `payment/request` 404 e
pulsante assente; health; avvio dell'immagine di produzione con healthcheck
verde; ritorno all'immagine precedente se il nuovo avvio fallisce. Esegui
anche i test esistenti del POS. `php -l` su ogni PHP toccato (in container).

## Consegna

Commit piccoli con `git commit --only` dei tuoi file. Alla fine scrivi
`napay-project/sip/SIP-036/HANDOFF-COD.md` (non committarlo): commit, file,
test eseguiti e non eseguiti, variabili env del POS in produzione (solo nomi),
patch proposte per gateway/orchestratore, rischi.
