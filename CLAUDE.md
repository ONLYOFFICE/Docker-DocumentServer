## Project Overview

ONLYOFFICE Docker-DocumentServer — single-container Docker image for ONLYOFFICE Docs. Supervisor runs the Docs programs (docservice, converter, metrics, example; adminpanel in EE/DE), nginx and cron are started by the entrypoint. The Enterprise/Developer image also bundles PostgreSQL, Redis and RabbitMQ (started via `service`); the Community image bundles none of them and has no database/broker/Redis settings at all.

## Tech Stack

Docker, Docker BuildX, Bash, Nginx, Supervisor, PostgreSQL/MySQL/MariaDB/MSSQL/Oracle/Dameng, Redis, RabbitMQ/ActiveMQ, Python (smoke tests)

## Project Structure

```
Dockerfile              — Community Edition image (Ubuntu 24.04 base; requires empty PRODUCT_EDITION)
Dockerfile.enterprise   — EE/DE image (PRODUCT_EDITION=-ee|-de): bundled PostgreSQL/Redis/RabbitMQ, MySQL/MSSQL clients, Oracle Instant Client
production.dockerfile   — Optional image without documentserver-example
docker-compose.yml          — Local dev CE (documentserver only, no bundled services)
docker-compose.enterprise.yml — Local dev EE (with postgres, rabbitmq, redis)
docker-compose.developer.yml  — Local dev DE (with postgres, rabbitmq, redis)
docker-bake.hcl         — BuildX config; picks Dockerfile or Dockerfile.enterprise by PRODUCT_EDITION, plus the -nonexample target
run-document-server.sh       — Entrypoint: initialization sequence and startup
config/supervisor/           — Supervisor service configs (ds-converter, ds-docservice, ds-example, ds-metrics, ds-adminpanel) and ds.conf group
config/supervisor/ds.conf.enterprise — Group config with adminpanel included (EE/DE only; CE image excludes ds-adminpanel.conf)
tests/                  — Integration tests: test.sh + compose configs (DB/AMQP/SSL matrix), smoke.py, lifecycle.sh (entrypoint secrets/upgrade/timeout scenarios)
fonts/                  — Extra fonts copied into /usr/share/fonts/truetype/ at build time (placeholder only)
oracle/                 — Oracle SQLPlus wrapper (EE/DE only)
.github/workflows/      — CI: 4testing-build (bake + smoke), docker-tests (weekly test matrix), stable-build, secure-rebuild, Trivy/ZAP scans
.github/scripts/smoke.py — Smoke tests run against built images by 4testing-build and secure-rebuild
.gitea/workflows/shellcheck.yml — ShellCheck of run-document-server.sh on PRs
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
cd tests && DOCUMENTSERVER_IMAGE=onlyoffice/documentserver-ee:local bash ./lifecycle.sh
```

Use `--platform linux/amd64` or `--platform linux/arm64` to select the image
architecture. Use `--build-arg PACKAGE_VERSION=<version>` and
`--build-arg PACKAGE_BASEURL=<url>` to select a specific package.
The `.deb` sha256 is taken from the signed apt repository for the default
`PACKAGE_BASEURL`; pass `--build-arg PACKAGE_SHA256=<sha256>` to verify a custom one.
CI uses `docker buildx bake -f docker-bake.hcl documentserver` with the variables
set in `.github/workflows/4testing-build.yml`.

## Key Patterns

- Single-container architecture: all services in one image via Supervisor
- Three editions: Community, Enterprise (-ee), Developer (-de)
- `run-document-server.sh` handles all configuration, DB init, service startup
- Settings go into `/etc/onlyoffice/documentserver/local.json` via the bundled `npm/json` tool, values passed through `process.env`
- Multi-arch support: amd64, arm64
- Multiple database backends via DB_TYPE environment variable (EE/DE only: `DB_AVAILABLE`/`REDIS_AVAILABLE`/`RABBITMQ_AVAILABLE`/`ADMINPANEL_AVAILABLE` are true only when PRODUCT_EDITION is set)
- `Data/.private` keeps the generated JWT/secure link secrets and the release marker; a changed marker means upgrade (tables recreated), no marker keeps tables unless `DS_DB_UPGRADE=true`
- `*_FILE` variants for `DB_PWD`, `JWT_SECRET`, `SECURE_LINK_SECRET`, `AMQP_URI`, `REDIS_SERVER_PASS`; `WAIT_TIMEOUT` (default 600 s) bounds the dependency waits
- MSSQL/Oracle are waited for until a real login works; on an abnormal exit the EXIT trap stops the services already started
- `GENERATE_FONTS` (default true) regenerates AllFonts.js and thumbnails at every start
- SSL/TLS with Let's Encrypt integration (Certbot)
- The container runs as root; the Supervisor programs run as user `ds`

## Review Focus

**Security**: JWT validation, SSL/TLS config, credential handling in entrypoint
**Shell**: `run-document-server.sh` is critical — quoting, error handling, DB initialization logic; DB passwords only via `PGPASSWORD`/`MYSQL_PWD`/`SQLCMDPASSWORD` or sqlplus stdin, never on the command line
**Docker**: Image size, layer count, base image updates
**Supervisor**: Service configs, process dependencies, restart policies
**Config**: Default ports, exposed services, database connection strings

## Git Workflow

- **Main branch**: `master`
- **Integration branch**: `develop` (current fixes land on `hotfix/vX.Y.Z` / `release/*` and are merged back)
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`
