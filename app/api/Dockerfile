# Stage 1: Install dependencies (cached layer)
FROM node:22-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Stage 2: Production image
FROM node:22-alpine

# Security: create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy dependencies from cached stage
COPY --from=deps /app/node_modules ./node_modules

# Copy application code
COPY . .

# Security: remove unnecessary files from image
RUN rm -rf .env .env.* .git tests *.md

# Security: set proper file ownership
RUN chown -R appuser:appgroup /app

# Security: run as non-root user
USER appuser

EXPOSE 5000

# Health check for Kubernetes readiness probes
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5000/api/search/admin/stats || exit 1

CMD ["node", "app.js"]
