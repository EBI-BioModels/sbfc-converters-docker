# BioModels Converters — Docker Compose (no Kubernetes)

Runs the full BioModels Converters stack (Tomcat webapp + MariaDB) using Docker Compose, replacing the EBI NFS / Kubernetes / LSF cluster dependencies. Designed to run on an AWS EC2 instance behind an Apache reverse proxy.

**External URL:** `https://biomodels.org/tools/converters`

## Prerequisites

- Docker Engine + Compose v2 (EC2) or Docker Desktop (local)
- Apache 2.4 with `mod_proxy`, `mod_proxy_http`, `mod_ssl`, `mod_rewrite` enabled
- The `sbfc-converters/sbfc/lib/` JARs present (checked out alongside this repo)

## First-time setup

```bash
cd sbfc-converters-aws-ec2
cp .env.example .env
# Edit .env and set DB_PASS and DB_ROOT_PASS to values of your choice
```

## Start

```bash
docker compose up -d --build
```

Tomcat listens on `127.0.0.1:8090` (localhost only — Apache handles external traffic).

### Local testing (before Apache is configured)

```bash
curl http://localhost:8090/tools/converters/
```

## Stop (keep data)

```bash
docker compose down
```

## Stop and wipe all data (full reset)

```bash
docker compose down -v
```

This removes only the named volumes declared in this compose file (`db_data`, `jobs_data`, `zip_data`, `ws_data`, `sbfc_logs`). Other containers and volumes on your machine are not affected.

## Database access

While containers are running:

```bash
# As the app user
docker compose exec db mysql -u bmappuser -p"${DB_PASS}" converters-dev

# As root
docker compose exec db mysql -u root -p"${DB_ROOT_PASS}" converters-dev
```

Useful queries:

```sql
SHOW TABLES;

-- monitor incoming jobs
SELECT id, id_MD5, fileName, finished FROM jobs ORDER BY id DESC LIMIT 10;

-- active sessions
SELECT * FROM convert_sessions;
```

## Architecture

| Component | Image | Notes |
|-----------|-------|-------|
| `tomcat` | built from `Dockerfile` | Tomcat 8.5 + JDK 8; serves `sbfcOnline.war` |
| `db` | `mariadb:10.6` | MariaDB used instead of MySQL 5.7 (no ARM64 image) and MySQL 8 (incompatible with the Connector/J 5.x driver bundled in the WAR) |

### Volume layout inside the `tomcat` container

| Path | Source |
|------|--------|
| `/data/converters/sbfc/lib/` | bind-mount from `../sbfc-converters/sbfc/lib/` |
| `/data/converters/sbfc/miriam.xml` | bind-mount from `../sbfc-converters/sbfc/miriam.xml` |
| `/data/converters/sbfc/sbfConverterOnline.sh` | copied into image from `sbfConverterOnline.sh` |
| `/data/converters/jobs/` | named volume `jobs_data` |
| `/data/converters/zip/` | named volume `zip_data` |
| `/data/converters/ws/` | named volume `ws_data` |
| `/data/converters/sbfc/log/` | named volume `sbfc_logs` |

### How conversions run

The webapp writes the uploaded model to `jobs/<id>.input`, then invokes `SBFC_COMMAND`:

```
/data/converters/sbfc/sbfConverterOnline.sh <ModelType> <ConverterName> /data/converters/jobs/<id>.input
```

The script runs the converter directly (no SSH or LSF cluster dispatch). When finished it writes `<id>.done`, which the webapp polls to detect completion.

## Limitations

**SBML2SBML** requires the native libSBML C library (JNI), which is not installed in the image. All other converters (SBML2BioPAX, SBML2XPP, SBML2Octave, SBML2SBGNML, etc.) work without it. To enable SBML2SBML, add to the `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install -y libsbml5-java && rm -rf /var/lib/apt/lists/*
```

## Deploying on AWS EC2

### 1. Install Docker

```bash
sudo yum update -y                          # Amazon Linux 2
sudo yum install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
# Re-login for the group change to take effect

# Compose v2 plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
     -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

### 2. Install Apache

```bash
sudo yum install -y httpd mod_ssl
sudo systemctl enable --now httpd
```

Enable the required modules (add to `/etc/httpd/conf/httpd.conf` if not present):

```apache
LoadModule proxy_module       modules/mod_proxy.so
LoadModule proxy_http_module  modules/mod_proxy_http.so
LoadModule rewrite_module     modules/mod_rewrite.so
LoadModule ssl_module         modules/mod_ssl.so
```

### 3. Obtain an SSL certificate (Let's Encrypt)

```bash
sudo yum install -y certbot python3-certbot-apache
sudo certbot --apache -d biomodels.org -d www.biomodels.org
```

### 4. Install the Apache virtual host config

```bash
sudo cp apache/biomodels.org.conf /etc/httpd/conf.d/biomodels.org.conf
# Edit the file and replace MAIN_PORT with the port of the main biomodels.org service
sudo apachectl configtest
sudo systemctl reload httpd
```

### 5. EC2 security group

Open inbound rules for:

| Port | Protocol | Source    |
|------|----------|-----------|
| 80   | TCP      | 0.0.0.0/0 |
| 443  | TCP      | 0.0.0.0/0 |

Do **not** open port 8090 — the container binds to `127.0.0.1` only.

### 6. Start the converters

```bash
cd sbfc-converters-aws-ec2
docker compose up -d --build
```

The converters are now reachable at `https://biomodels.org/tools/converters`.

---

## Apache config explained

The config lives in `apache/biomodels.org.conf`. Key behaviour:

- Port 80 redirects permanently to HTTPS.
- `/tools/converters` is proxied to `http://localhost:8090/tools/converters` (the Docker container). This block must appear **before** the catch-all proxy rule.
- `/` (everything else) is proxied to the main biomodels.org service — replace `MAIN_PORT` with the actual port.
- The Tomcat context path is `/tools/converters` (set by naming the context descriptor `tools#converters.xml` inside the image), so paths generated by the webapp match the external URL exactly — no rewriting needed.

---

## Credentials

Credentials are read from `.env` (gitignored). Copy `.env.example` to `.env` and fill in values before starting. The `DB_PASS` value is used by both MariaDB and the Tomcat JDBC pool; they must match.
