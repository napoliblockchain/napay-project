FROM rclone/rclone:1.76.0@sha256:7cbeec24a44f206067597c0368be4de90ae19a64d5113c7d1938bd737a81e466 AS rclone
FROM alpine:3.23@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2
RUN apk add --no-cache bash gnupg coreutils ca-certificates \
    && mkdir -p /opt/napay/docker/backup-offsite
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone
COPY encrypt.sh upload.sh private-inputs.sh tools.sh /opt/napay/docker/backup-offsite/
ENV HOME=/tmp
USER 1000:1000
ENTRYPOINT ["/bin/bash", "/opt/napay/docker/backup-offsite/tools.sh"]
