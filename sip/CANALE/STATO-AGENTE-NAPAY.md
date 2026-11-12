# Stato agente Napay

Aggiornato: 2026-11-12 19:2x. Scrive solo l'agente Napay.

## In corso

- C4 parte D (inviti operatore), worktree
  `/var/www/blockchain-napoli/napay-worktrees/napay-backoffice-c4`, branch
  `feature/v2-napay-backoffice-c4`. Avvio: prossimo ciclo del canale.

## File che sto modificando adesso

Nessuno nel checkout principale (`napay-project`, `napay-project/napay`).
Nel worktree C4 (solo file riservati, nessuno ancora creato):
- `migrations/m261112_140000_create_pos_operator_invitations.php`
- `models/PosOperatorInvitations.php`
- `controllers/PosInvitationController.php`, `views/pos-invitation/*`
- `components/pos/management/*`, `controllers/PosManagementController.php`,
  `views/pos-management/*` (azioni invito lato gestore)
- `mail/posOperatorInvitation*.php`
- `tests/application/pos-management.php`, `tests/application/pos-invitations.php`,
  `tests/docker/pos-management.sh`

Nell'orchestratore scrivo solo: `sip/CANALE/RISPOSTE-AGENTE-NAPAY.md`,
`sip/CANALE/STATO-AGENTE-NAPAY.md`, `sip/SIP-021/C4-*.md` (miei),
`sip/SIP-022/B0-{ESITI,HANDOFF}.md` e `docker/btcpay-regtest/*` (solo sul
branch `feature/btcpay-regtest-b0`, worktree `orchestrator-btcpay-b0`).

## Risorse Docker in uso

Solo stack di test usa-e-getta, nomi `napay-runtime-test-*`,
`btcpay-regtest-test-*`, `btcpay-topo-*`, rimossi a fine esecuzione.
Nessuno stack persistente avviato; sandbox condivisa mai toccata.

## Prossimo passo / in attesa di

- Prossimo: contratto D già approvato -> migration e modello inviti con test
  su DB usa-e-getta.
- In attesa del master: review B0 (RV1-RV4) e integrazione delle patch
  gateway/egress; poi fase 2 B0.
