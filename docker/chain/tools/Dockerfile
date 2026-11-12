# Strumenti chain (sviluppo e produzione, SIP-017): genesis QBFT, deploy e mint TTSToken.
# OpenZeppelin 2.4.0 e solc 0.5.17 sono le versioni del contratto TTS in produzione.
# npm audit: GHSA-88g8 (Initializable) e GHSA-7grf (ERC165Checker) non si applicano, TTSToken non li usa.
FROM node:22.23.5-alpine3.24

WORKDIR /tools
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund --ignore-scripts
COPY contracts contracts
COPY init.mjs deploy.mjs mint.mjs ./

# volume dati chain: scrivibile da node (uid 1000), letto da besu con lo stesso uid
RUN mkdir /data && chown node:node /data
USER node
