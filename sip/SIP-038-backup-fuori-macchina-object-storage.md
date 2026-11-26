# SIP-038 - Backup fuori macchina su Object Storage Contabo

- Stato: OPEN
- Area: Rilascio / DevOps / Backup
- Repo: orchestratore, `napay`
- Branch target: `feature/v2-*`
- Segnalato: 2026-11-25 (Object Storage già disponibile, segnalato dall'utente)

## Contesto
I backup notturni della VPS A (database Napay e wallet, `backup-daily.sh`, ore 03:30, 14 giorni)
restano sul disco della stessa VPS: se la VPS si perde, si perdono anche i backup. La chain della
VPS C ha solo un backup cifrato copiato a mano il 2026-11-24. Il piano su Contabo comprende già un
Object Storage S3 compatibile, "Object Storage EU", 250 GB, regione European Union, vuoto
(nessun bucket, verificato dall'utente il 2026-11-25), auto-scaling spento.

## Proposta
- Un bucket dedicato ai backup Napay, creato dall'utente.
- Credenziali S3 dedicate, con il minimo dei permessi che Contabo consente (preferibile: solo
  scrittura, nessuna cancellazione), in un file privato sulla VPS (0600, fuori dai repository).
- Dopo il backup notturno, invio dei file **cifrati prima dell'invio** sul server, con una chiave
  il cui segreto non sta sulla VPS (cifratura asimmetrica: la VPS ha solo la chiave pubblica).
- Retention sul bucket più lunga di quella locale (da decidere con l'utente, es. 90 giorni),
  rispettando i 250 GB.
- VPS C: backup settimanale cifrato della chain (chiavi del validatore e del faucet, genesis,
  database) con lo stesso meccanismo.
- Prova di ripristino documentata: download, decifratura, ripristino su stack usa-e-getta.

## Criteri di accettazione
- Ogni notte i backup di A arrivano sul bucket cifrati; un errore di invio è visibile (log e
  stato del timer) senza bloccare il backup locale.
- Un file sul bucket non è leggibile senza la chiave privata, che non sta sulle VPS.
- Ripristino provato da bucket a stack usa-e-getta, con conteggi uguali all'originale.
- Nessuna credenziale o segreto nei repository e nei log.

## Impatto
- Orchestratore: invio dopo `backup-daily.sh` e unità systemd; script per la chain.
- VPS A e C: file privato delle credenziali, chiave pubblica di cifratura, timer.
- Contabo: bucket e credenziali (azioni dell'utente).

## Note implementative
- Strumento di invio da scegliere riusando soluzioni esistenti e mantenute (client S3 ufficiale o
  rclone in container), senza dipendenze sull'host oltre a Docker.
- Verificare quali politiche di accesso offre l'Object Storage Contabo prima di promettere la sola
  scrittura; se non disponibile, indicarlo e compensare con versioning o retention lato bucket.
- Dipende da SIP-036 (backup locale già attivo).

## Verifica repository
- Da compilare a lavoro concluso.

## Avvio 2026-11-26

Piano approvato dall'utente: backup esterno prioritario, privacy in parallelo.
Implementazione isolata su feature/backup-offsite, base 72e47f6.
Micro-step e limiti: [IMPLEMENTAZIONE.md](SIP-038/IMPLEMENTAZIONE.md).
Primo passo solo cifratura offline; nessun accesso S3/VPS, timer o retention
attivati. Lo stato globale resta aperto fino al ripristino da storage provato.

Passi A/B sviluppati e collaudati: cifratura, contenitore versionato, uploader
HTTPS e prova completa file su S3 TLS locale (19+20+10 controlli). Dettagli e
limiti nell'allegato. SIP globale non chiuso: nessun bucket reale configurato,
nessun timer collegato, ripristino database/chain e policy ancora da completare.
