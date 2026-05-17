# ── Stage 1: Build the React app ───────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ── Stage 2: Serve with Nginx (distroless) ─────────────────────────────────────
# nginxinc/nginx-unprivileged is the hardened, non-root Nginx image
# maintained by the official Nginx team. It:
# - Runs as non-root (uid 101) by default
# - Has a minimal OS footprint
# - Receives prompt security patches
FROM nginxinc/nginx-unprivileged:1.27-alpine AS production

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built static files
COPY --from=build /app/dist /usr/share/nginx/html

# nginx-unprivileged listens on 8080 instead of 80 (non-root cannot bind <1024)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
