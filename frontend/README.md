# SRE Control Plane - Frontend

Vue 3 single-page application for monitoring and controlling the backend API.

## Features

- 📊 **Real-time Dashboard** - Health status, metrics, and version info
- 💥 **Chaos Engineering** - Control probes, inject delays, trigger failures
- 🔍 **API Explorer** - Interactive endpoint testing
- ⚙️ **Environment Viewer** - Runtime configuration and headers
- 🎨 **Modern UI** - Tailwind CSS with dark theme
- 📈 **Live Metrics** - Auto-refreshing every 5 seconds

## Tech Stack

- **Framework:** Vue 3 (Composition API with `<script setup>`)
- **Build Tool:** Vite
- **Styling:** Tailwind CSS
- **State Management:** Pinia
- **Router:** Vue Router 4
- **HTTP Client:** Axios
- **Charts:** ApexCharts
- **Web Server:** nginx (production)

## Development

```bash
# Install dependencies
npm install

# Run dev server (http://localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Environment Variables

Create `.env` file:

```env
VITE_API_URL=http://localhost:8080
```

## Docker Build

```bash
# Build image
docker build -t frontend:latest .

# Run container
docker run -p 8080:8080 \
  -e VITE_API_URL=http://backend:8080 \
  -e ENVIRONMENT=development \
  frontend:latest
```

## Kubernetes Deployment

Manifests are located in `flux/apps/frontend/`:

- `base/` - Common resources (deployment, service, ingress)
- `overlays/develop/` - Development environment
- `overlays/staging/` - Staging environment
- `overlays/production/` - Production environment

Deploy with Flux CD or kubectl:

```bash
# Apply with Kustomize
kubectl apply -k flux/apps/frontend/overlays/develop

# Verify deployment
kubectl -n frontend get pods
kubectl -n frontend get svc
kubectl -n frontend get ingress
```

## CI/CD

GitHub Actions workflows:

- `.github/workflows/build-develop.yml` - Auto-build from develop branch
- Multi-platform builds (amd64, arm64)
- Trivy security scanning
- Push to GitHub Container Registry

## Architecture

```
Browser
   ↓
Vue 3 Frontend (nginx:8080)
   ↓ HTTP/JSON
Go Backend (:8080)
   ↓
Kubernetes Services
```

## Pages

- **Dashboard** (`/`) - Health status and metrics overview
- **Chaos Engineering** (`/chaos`) - Probe controls and failure injection
- **API Explorer** (`/api-explorer`) - Interactive endpoint testing
- **Environment** (`/environment`) - Runtime configuration

## Production Build

The production build uses a multi-stage Dockerfile:

1. **Builder stage:** npm install + build with Vite
2. **Runtime stage:** nginx serving static files

Features:
- Non-root user (10001)
- Read-only root filesystem
- Security headers
- Gzip compression
- Health check endpoint (`/health`)
- Runtime environment injection

## License

Part of the SRE DevOps blueprint for Udemy course.
