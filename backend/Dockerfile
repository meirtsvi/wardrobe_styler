# ai-gateway (PLAN §7.1). Build context is the repo root so ../shared is available.
FROM node:22-slim AS build
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./backend/
RUN cd backend && npm ci --no-audit --no-fund
COPY shared ./shared
COPY backend ./backend
RUN cd backend && npm run build

FROM node:22-slim
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/backend/package.json /app/backend/package-lock.json ./backend/
RUN cd backend && npm ci --omit=dev --no-audit --no-fund
COPY --from=build /app/backend/dist ./backend/dist
COPY shared ./shared
EXPOSE 8080
CMD ["node", "backend/dist/backend/src/index.js"]
