# syntax=docker/dockerfile:1

# Stage 1: Build the Vue application
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --include=dev

# Copy source code
COPY . .

# Build arguments for versioning
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

# Build the application
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:1.27-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy custom nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Create runtime environment config script
RUN echo '#!/bin/sh' > /docker-entrypoint.d/40-generate-env-config.sh && \
    echo 'cat <<EOF > /usr/share/nginx/html/config.js' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo 'window.__ENV__ = {' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  VITE_API_URL: "${VITE_API_URL}",' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  VITE_UPTRACE_DSN: "${VITE_UPTRACE_DSN}",' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  ENVIRONMENT: "${ENVIRONMENT}",' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  VERSION: "${VERSION}",' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  COMMIT: "${COMMIT}",' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '  BUILD_DATE: "${BUILD_DATE}"' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo '};' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    echo 'EOF' >> /docker-entrypoint.d/40-generate-env-config.sh && \
    chmod +x /docker-entrypoint.d/40-generate-env-config.sh

# Create non-root user
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Labels for metadata
LABEL org.opencontainers.image.title="SRE Frontend" \
      org.opencontainers.image.description="Vue 3 SPA for SRE Control Plane" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
