# SIP-037 - Rilascio automatico sulla VPS al merge in main/master

- Stato: OPEN
- Area: Rilascio / DevOps
- Repo: orchestratore, `napay`, `pos`, `poawallet`
- Branch target: `feature/v2-*` (workflow attivi solo su `main`/`master`)
- Segnalato: 2026-11-25 (richiesta utente: come per gold-manager e sonarpush)

## Contesto
Dopo SIP-036 ogni rilascio sulla VPS A (167.86.84.85) è manuale: scaricare il commit e
lanciare lo script di rilascio del componente. Gli script esistono già e sono sicuri:
controllo preliminare, backup del database prima delle migration, attesa dello stato sano,
ritorno alla versione precedente. Manca solo l'avvio automatico al merge. Il repository
è pubblico (organizzazione napoliblockchain) e il server contiene dati di soci e pagamenti:
GitHub non deve ottenere una shell sulla VPS.

## Proposta
- Un workflow GitHub Actions per repository, avviato dal push su `main`/`master` (cioè dal
  merge della PR) e a mano; un solo rilascio alla volta per repository.
- Il workflow si collega in SSH alla VPS A con una chiave **dedicata al repository**. Sulla
  VPS la chiave è legata a un **comando forzato**: niente shell, niente port forwarding, niente
  comandi scelti da GitHub. La chiave del repository napay può solo rilasciare Napay, e così via.
- Un utente di sistema dedicato, senza password né shell interattiva, può eseguire con sudo
  **solo** lo script di rilascio di root, con il nome del componente come unico argomento.
- Lo script di rilascio (di proprietà di root, fuori dai repository clonati):
  - accetta solo i componenti noti; blocco unico per tutti i rilasci;
  - aggiorna il clone del componente all'ultimo commit di `main`/`master` (solo avanzamento,
    rifiuta modifiche locali);
  - lancia lo script di rilascio esistente con il file env privato;
  - registra esito, commit e durata in un registro locale; nessun segreto nell'output.

| Repository | Branch | Rilascio |
| --- | --- | --- |
| napay | master | `napay/docker/deploy.sh` |
| pos | master | `pos/v2/docker/deploy.sh` |
| poawallet | main | `deploy-wallet.sh` dell'orchestratore |
| orchestratore | main | `deploy-gateway.sh`, poi `deploy-wallet.sh` |

- Fuori dal rilascio automatico: la chain della VPS C (validatore, cambia di rado) e BTCPay
  della VPS B. Restano manuali.

## Criteri di accettazione
- Un merge in `main`/`master` rilascia il componente sulla VPS A senza intervento manuale.
- La chiave di un repository non può avviare il rilascio di un altro componente né aprire una
  shell (provato).
- Rilasci simultanei non si sovrappongono; un rilascio fallito lascia in servizio la versione
  precedente (comportamento degli script esistenti).
- Nessun segreto nei log di GitHub né nel registro locale.
- Guida passo passo per l'installazione (utente, chiavi, sudo, segreti GitHub) nel registro
  della VPS A in documents.

## Impatto
- Nuovi: un workflow per repository, lo script di rilascio di root con il suo test, la guida.
- Sulla VPS A: utente dedicato, `authorized_keys` con comandi forzati, regola sudo limitata.
- Su GitHub: segreti del repository (host, porta, chiave privata dedicata, impronta dell'host).

## Note implementative
- Prerequisito: branch `develop` e `main`/`master` allineati al branch di rilascio (PR del
  2026-11-25).
- L'impronta della chiave dell'host è un segreto fisso, non letta a ogni esecuzione: una VPS
  sostituita non riceve rilasci finché l'impronta non viene aggiornata.
- I repository non hanno ancora una CI (SIP-010): il controllo è quello degli script di
  rilascio (controllo preliminare e backup). Quando esisterà una CI, il rilascio partirà solo
  dopo il suo esito positivo.
- Clienti con divieto di rilascio automatico (ilnotturno, gestaccessi) non sono coinvolti.

## Verifica repository
- Da compilare a lavoro concluso.
