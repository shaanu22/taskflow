# ── Stage 1: Build the React app ───────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app
# Dependencies first (caching).
COPY package.json package-lock.json ./
RUN npm ci
# Source code.
COPY . .
# Build the static files. This runs `react-scripts build` or `vite build`
# and produces a /app/dist (or /app/build) directory of static assets.
RUN npm run build
# ── Stage 2: Serve with Nginx ──────────────────────────────────────────────────
FROM nginx:1.25-alpine AS production
# Remove the default Nginx configuration.
RUN rm /etc/nginx/conf.d/default.conf
# Add our custom Nginx configuration.
COPY nginx.conf /etc/nginx/conf.d/
# Copy the built static files into the Nginx web root.
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]