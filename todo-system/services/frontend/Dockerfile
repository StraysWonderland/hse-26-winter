FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
# Cache mount: npm's download cache survives between builds, but is not part of any image layer.
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund
COPY . .
RUN npm run build

# Static files only: no Node at runtime. Unprivileged nginx listens on 8080, runs as uid 101.
FROM nginxinc/nginx-unprivileged:1.28-alpine
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="frontend" \
      org.opencontainers.image.description="TODO system: React UI behind nginx" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV APP_VERSION=${APP_VERSION} \
    TODO_SERVICE_URL=http://todo-service:8080 \
    ACTIVITY_SERVICE_URL=http://activity-service:8080 \
    NGINX_RESOLVER=127.0.0.11
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
