FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# Default JSON account store lives under /app/data. Mount a durable volume
# here (or set ACCOUNT_STORE_PATH to an external store) — container layer
# storage is ephemeral and will lose linked accounts on redeploy.
RUN mkdir -p /app/data && chown -R node:node /app
VOLUME ["/app/data"]
USER node
EXPOSE 8080
CMD ["node", "dist/index.js"]
