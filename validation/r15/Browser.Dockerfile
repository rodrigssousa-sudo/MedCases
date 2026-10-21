FROM mcr.microsoft.com/playwright:v1.51.1-noble
WORKDIR /opt/test
RUN npm init -y && npm install --save-exact playwright@1.51.1 firebase-tools@13.35.1
ENV NODE_PATH=/opt/test/node_modules
CMD ["node", "/tests/b2.cjs"]
