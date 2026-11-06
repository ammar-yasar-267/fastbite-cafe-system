# FastBite order-service - packaged on its own. Listens on port 3002.
FROM node:20-alpine

ENV NODE_ENV=production
WORKDIR /app

# Install dependencies first so Docker can reuse this layer when only the code changes.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY index.js ./

# Never run as root inside the container.
USER node

ENV PORT=3002
EXPOSE 3002

# Docker (and docker compose) use this to know when the service is really ready.
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:3002/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "index.js"]
