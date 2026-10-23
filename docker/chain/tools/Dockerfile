# Strumenti chain di sviluppo (profilo compose "chain"): genesis QBFT e deploy TTSToken.
# Solo uso locale: OpenZeppelin 2.4.0 e solc 0.5.17 sono le versioni del contratto TTS in produzione.
FROM node:20-alpine

WORKDIR /tools
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund --ignore-scripts
COPY contracts contracts
COPY init.mjs deploy.mjs ./

# volume dati chain: scrivibile da node (uid 1000), letto da besu con lo stesso uid
RUN mkdir /data && chown node:node /data
USER node
