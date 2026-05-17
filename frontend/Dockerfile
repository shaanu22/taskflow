# ── Stage 1: Build the React app ───────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ── Stage 2: Serve with Nginx (hardened) ───────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.27-alpine AS production

# Switch to root temporarily to upgrade packages
USER root
RUN apk upgrade --no-cache

# Switch back to non-root nginx user
USER nginx

COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
# cache-bust: 1778985229
