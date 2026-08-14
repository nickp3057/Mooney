FROM node:22-alpine

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY plaid.js storage.js server.js ./

# Persisted across restarts via the volume mount in docker-compose.yml.
VOLUME ["/app/data"]

EXPOSE 4001

CMD ["node", "server.js"]
