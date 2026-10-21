FROM mcr.microsoft.com/playwright:v1.51.1-noble@sha256:146d046a8d79a1b3a87596c4457b0b1c47f811bf4fc2cc1b99e873ae7f1cbbbd
WORKDIR /opt/test
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
ENV NODE_PATH=/opt/test/node_modules
CMD ["node", "/tests/b2.cjs"]
