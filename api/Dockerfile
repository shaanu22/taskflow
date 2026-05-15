# api/Dockerfile
# ── Stage 1: Base ──────────────────────────────────────────────────────────────
# We start from the official Node.js image. We pin to a specific version — not
# "latest" — because "latest" changes and breaks builds unpredictably.
FROM node:20-alpine AS base
# Set the working directory inside the container. All subsequent commands
# run relative to this path.
WORKDIR /app
# ── Stage 2: Dependencies ──────────────────────────────────────────────────────
FROM base AS deps
# Copy package files first. This is deliberate — because package.json and
# package-lock.json change less frequently than source code, Docker can cache
# this layer. If your source code changes but your dependencies don't, Docker
# skips the npm install entirely on the next build.
COPY package.json package-lock.json ./
# Install only production dependencies.
RUN npm ci --only=production
# ── Stage 3: Build ─────────────────────────────────────────────────────────────
FROM deps AS build
# Install all dependencies (including devDependencies needed for the build).
RUN npm ci
# Now copy the source code. This layer changes frequently, but that's fine —
# it comes after the dependency layer.
COPY . .
# If your API has a build step (TypeScript compilation, etc.), run it here.
# RUN npm run build
# ── Stage 4: Production ────────────────────────────────────────────────────────
FROM base AS production
# Create a non-root user. Running as root inside a container is a security risk.
# If an attacker compromises your container, they should not get root access.
RUN addgroup --system --gid 1001 nodejs && \
adduser --system --uid 1001 nodeuser
# Copy only what we need to run the app — production dependencies and source.
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/src ./src
COPY --from=build /app/package.json ./
# Switch to the non-root user.
USER nodeuser
# Document which port the app listens on. This is metadata — it does not
# actually publish the port. That happens at runtime.
EXPOSE 3000
# The command that runs when the container starts.
CMD ["node", "src/index.js"]