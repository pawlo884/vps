# Multi-stage build: React (Vite/CRA) -> nginx
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Vite: zmienne VITE_* muszą być dostępne podczas buildu
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}

# dist = Vite, build = Create React App
ARG BUILD_OUTPUT=dist
ARG BUILD_CMD=build

RUN npm run ${BUILD_CMD}

FROM nginx:alpine AS production

COPY nginx.conf /etc/nginx/conf.d/default.conf

ARG BUILD_OUTPUT=dist
COPY --from=build /app/${BUILD_OUTPUT} /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
