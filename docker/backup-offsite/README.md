# Off-site backup tools - SIP-038

## Current scope

`encrypt.sh` and `upload.sh` are separate tools, not an installed backup service.
The Dockerfile pins Alpine 3.23 and official rclone 1.76.0 by digest. It installs
Bash, GnuPG, coreutils and system CAs from Alpine's signed package repository;
those package versions are not snapshot-pinned. Default user is 1000:1000.
No timer, production bucket or VPS has been configured. Do not activate yet.

```sh
bash docker/backup-offsite/encrypt.sh \
  /absolute/private/recipient-public.gpg FULL_PRIMARY_FINGERPRINT \
  /absolute/private/backups/napay-20261126-daily.sql.gz \
  /absolute/private/encrypted
```

- The input backup must be complete, nonempty, owner-readable and owner-only.
- The output directory must already exist, be owned by the current user and
  have owner-only read/write/traverse permissions. Inputs must use canonical
  absolute paths outside this repository, without symbolic links.
- The public key must be owned by the current user and not group/world
  writable. A full primary-key fingerprint must be verified independently.
- The recovery private key must stay off the production machines. The script
  rejects private-key files and bundles containing multiple primary keys.
- The script uses a fresh isolated temporary keyring, never the user's keyring
  or an online key lookup. Output is a binary OpenPGP file with AES256; GnuPG
  enforces recipient usability. No backup filename is embedded in the payload.
- Output is published atomically as `<source-basename>.gpg`, mode 0600, without
  replacement. A duplicate destination is an explicit error, not an upload
  retry policy. Failed operations clean their own temporary files only.
- The source backup is never changed or deleted. No retention policy is applied.
- Logs contain generic outcomes, not backup content, key material or raw GPG
  diagnostics. Do not enable shell tracing around private configuration.

OpenPGP integrity checking detects ciphertext damage; encryption alone does
not authenticate who produced an archive. Storage permissions and the later
restore procedure must account for replacement of an object by an attacker.

## Offline tests

```sh
bash tests/backup-offsite.sh
bash tests/backup-offsite-transport.sh
```

Tests generate disposable recovery keys under a private temporary directory;
they never use production keys, S3, Docker, a database or a network service.
Recovery writes into the disposable directory only. Real recovery must write
into a private temporary file and publish it only after GPG succeeds; GPG can
emit partial plaintext before reporting an integrity failure.

## Container and S3 upload

```sh
docker build -t napay/backup-offsite:sip038-test docker/backup-offsite
bash tests/backup-offsite-e2e.sh
```

The e2e test uses real rclone and a disposable TLS S3 fixture on an internal
Docker network. It publishes no host ports and removes its containers/network.
It tests data recovery, TLS trust/hostname failures, invalid credentials,
duplicate retries and refusal to replace a different existing remote object.
This is not a Contabo policy test, a MySQL restore or a Besu restore.

The runtime commands are `encrypt`, `upload` and `version`. Mount only the
inputs needed by each phase, use the host UID/GID for the private files and:

- Both phases: `--read-only --cap-drop ALL --security-opt no-new-privileges`,
  `--memory 256m --cpus 1 --pids-limit 64`, private temporary storage such as
  `--tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m`. Never mount the Docker socket.
- Encryption: `--network none`, public recipient key and backup mounted `:ro`,
  encrypted output directory writable. Never mount the recovery private key.
- Upload: encrypted file, private configuration and optional public CA mounted
  `:ro`; do not mount the original plaintext backup. Network must reach the
  configured HTTPS endpoint; the production egress deployment remains pending.

Upload usage inside the container:

```sh
upload --check /inputs/config.env /inputs/archive.gpg
upload /inputs/config.env /inputs/archive.gpg
```

Optional third argument is an additional trusted CA file. `--check` performs
local validation only, never a network request or authentication test. Config
syntax is literal `KEY=value`, without quotes, interpolation or shell commands;
all six fields in `config.env.example` are required. Keep actual credentials in
an owner-only file outside repositories. Do not pass them as Docker environment
variables, command arguments or build arguments.

The uploader accepts only asymmetric OpenPGP envelopes, including GnuPG 2.4
AEAD packets. Packet inspection cannot verify encrypted integrity without the
recovery key. Remote names include SHA256 of the ciphertext; `--immutable` and
`--checksum` protect existing objects. The uploader never uses sync/delete or
creates buckets. Rclone may require metadata read permissions, not write-only.
Timeouts and retries are finite; raw SDK diagnostics are deliberately suppressed.
Errors preserve the local archive. SHA256 here is not a producer signature.

## Outstanding

- Contabo credentials, real bucket policies, object versioning/retention and
  live-provider validation; approval of endpoint/bucket and key custody.
- A durable manifest of backup sets and automatic retry selection.
- Integration with existing local backup service and failure reporting.
- Consistent chain backup, external key custody, download and full restore tests.
- User approval of remote retention, bucket policies and production activation.

## Durable encrypted sets

`seal-set` prepares 1-16 immutable source backups as one directory with a
`manifest.sha256` over the ciphertext files. The private queue directory must
already exist. Inputs are sorted, and the set ID includes the recipient
fingerprint, source names and source hashes. Repeating the same inputs reuses
validated ciphertext; input order does not create a second set.

```sh
bash docker/backup-offsite/seal-set.sh /private/public.gpg FULL_FINGERPRINT \
  /private/queue /private/backups/napay.sql.gz /private/backups/wallet.sql.gz
bash docker/backup-offsite/seal-set.sh --verify /private/queue/set-SET_ID
```

The container dispatcher also accepts `seal-set`. Publish is atomic and never
replaces an existing set. A failed encryption leaves no completed set; stale
staging from an abrupt host crash is not automatically deleted. Source files
must be completed immutable backups, not live databases. Source hashes are
checked again before and after encryption. The checksum manifest is local and
is not a producer signature or an uploaded remote manifest.

`bash tests/backup-offsite-set.sh` verifies exact recovery, retry identity,
input order, corruption, path/permission checks and concurrent publication.
This adds no timer, database access, remote upload or retention policy.
