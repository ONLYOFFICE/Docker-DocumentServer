## Project Overview

ONLYOFFICE Docker-DocumentServer — single-container Docker image for ONLYOFFICE Docs with all services (docservice, converter, nginx, PostgreSQL, Redis, RabbitMQ) managed by Supervisor.

## Tech Stack

Docker, Docker BuildX, Bash, Nginx, Supervisor, PostgreSQL/MySQL/MariaDB/MSSQL/Oracle, Redis, RabbitMQ/ActiveMQ

## Project Structure

```
Dockerfile              — Main image (Ubuntu 24.04 base)
production.dockerfile   — Optional image without documentserver-example
docker-compose.yml          — Local dev CE (documentserver only, no bundled services)
docker-compose.enterprise.yml — Local dev EE (with postgres, rabbitmq, redis)
docker-compose.developer.yml  — Local dev DE (with postgres, rabbitmq, redis)
docker-bake.hcl         — BuildX multi-platform config
run-document-server.sh       — Entrypoint: initialization sequence and startup
config/supervisor/           — Supervisor service configs (ds-converter, ds-docservice, ds-example, ds-metrics, ds-adminpanel)
config/supervisor/ds.conf.enterprise — Group config with adminpanel included (EE/DE only)
tests/                  — Integration tests (DB/AMQP/SSL matrix)
fonts/                  — Custom fonts directory
oracle/                 — Oracle SQLPlus wrapper
```

## Build & Run

```bash
# Build Community, Enterprise or Developer Edition locally
docker build -t onlyoffice/documentserver:local .
docker build -f Dockerfile.enterprise -t onlyoffice/documentserver-ee:local .
docker build -f Dockerfile.enterprise --build-arg PRODUCT_EDITION=-de -t onlyoffice/documentserver-de:local .

# Run
docker run -i -t -d -p 80:80 onlyoffice/documentserver:local

# Docker Compose Community Edition
TAG=local docker compose up -d --build

# Docker Compose Enterprise Edition
TAG=local docker compose -f docker-compose.enterprise.yml up -d --build

# Run tests
cd tests && config=standalone.yml bash ./test.sh
```

Use `--platform linux/amd64` or `--platform linux/arm64` to select the image
architecture. Use `--build-arg PACKAGE_VERSION=<version>` and
`--build-arg PACKAGE_BASEURL=<url>` to select a specific package.
CI uses `docker buildx bake -f docker-bake.hcl documentserver` with the variables
set in `.github/workflows/4testing-build.yml`.

## Key Patterns

- Single-container architecture: all services in one image via Supervisor
- Three editions: Community, Enterprise (-ee), Developer (-de)
- `run-document-server.sh` handles all configuration, DB init, service startup
- Multi-arch support: amd64, arm64
- Multiple database backends via DB_TYPE environment variable
- SSL/TLS with Let's Encrypt integration (Certbot)
- Non-root execution possible

## Review Focus

**Security**: JWT validation, SSL/TLS config, credential handling in entrypoint
**Shell**: `run-document-server.sh` is critical — quoting, error handling, DB initialization logic
**Docker**: Image size, layer count, base image updates
**Supervisor**: Service configs, process dependencies, restart policies
**Config**: Default ports, exposed services, database connection strings

## Git Workflow

- **Main branch**: `master`
- **Integration branch**: `develop`
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`
