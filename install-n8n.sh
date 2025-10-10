#!/usr/bin/env bash
set -euo pipefail

# =============================
# Config (env-aware defaults)
# Override with: sudo -E VAR=... bash install-n8n.sh
# =============================
DOMAIN="${DOMAIN:-n8n.gobotify.com}"        # e.g. 989.gobotify.com
EMAIL="${EMAIL:-}"                          # empty -> certbot registers without email
N8N_PORT="${N8N_PORT:-5678}"
N8N_HOST="${N8N_HOST:-$DOMAIN}"             # n8n internal host setting
COMPOSE_DIR="${COMPOSE_DIR:-/opt/n8n}"
SITE_NAME="${SITE_NAME:-n8n}"               # nginx site name
NGINX_SITE_PATH="/etc/nginx/sites-available/${SITE_NAME}"
NGINX_SITE_LINK="/etc/nginx/sites-enabled/${SITE_NAME}"

# =============================
# Helpers
# =============================
log() { echo -e "\n\033[1;32m=> $*\033[0m"; }
err() { echo -e "\n\033[1;31m!! $*\033[0m" >&2; }

# =============================
# Root check
# =============================
if [[ $EUID -ne 0 ]]; then
  err "Please run as root (e.g., sudo -E DOMAIN=... bash install-n8n.sh)"
  exit 1
fi

# =============================
# Update & essentials
# =============================
log "Updating apt and installing prerequisites..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

# =============================
# Install Docker (official repo)
# =============================
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  log "Docker already installed. Skipping."
fi

# =============================
# docker-compose v1 (optional)
# =============================
if ! command -v docker-compose >/dev/null 2>&1; then
  log "Installing docker-compose (apt)..."
  apt-get install -y docker-compose || true
else
  log "docker-compose already installed. Skipping."
fi

# =============================
# Create n8n compose stack
# =============================
log "Creating n8n docker compose at ${COMPOSE_DIR}..."
mkdir -p "$COMPOSE_DIR"
cat > "${COMPOSE_DIR}/docker-compose.yml" <<'YML'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    tty: true
    stdin_open: true
    environment:
      N8N_METRICS: "true"
      QUEUE_HEALTH_CHECK_ACTIVE: "true"
      N8N_RUNNERS_ENABLED: "true"
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      N8N_HOST: "REPLACE_N8N_HOST"
      N8N_PROTOCOL: "https"
      WEBHOOK_URL: "https://REPLACE_N8N_HOST"

volumes:
  n8n_data:
YML

# Inject host into compose
sed -i "s/REPLACE_N8N_HOST/${N8N_HOST//\//\\/}/g" "${COMPOSE_DIR}/docker-compose.yml"

# =============================
# Start n8n
# =============================
log "Starting n8n container..."
cd "$COMPOSE_DIR"
if command -v docker compose >/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

# =============================
# Install Nginx
# =============================
if ! command -v nginx >/dev/null 2>&1; then
  log "Installing Nginx..."
  apt-get install -y nginx
  systemctl enable --now nginx
else
  log "Nginx already installed. Skipping."
fi

# =============================
# Minimal HTTP server block for ACME
# =============================
log "Configuring minimal HTTP server for ${DOMAIN} (for certificate issuance)..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

cat > "$NGINX_SITE_PATH" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    # Allow Certbot HTTP-01 challenge
    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/html;
    }
    location / {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
EOF

ln -sf "$NGINX_SITE_PATH" "$NGINX_SITE_LINK"
# remove default if present (to avoid conflicts)
if [[ -f /etc/nginx/sites-enabled/default ]]; then
  rm -f /etc/nginx/sites-enabled/default
fi

nginx -t
systemctl reload nginx

# =============================
# Install Certbot and get cert
# =============================
log "Installing Certbot (Nginx plugin)..."
apt-get install -y certbot python3-certbot-nginx

log "Requesting Let's Encrypt certificate for ${DOMAIN}..."
if [[ -n "$EMAIL" ]]; then
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" || true
else
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || true
fi

# =============================
# Full HTTPS reverse proxy for n8n
# =============================
log "Writing full HTTPS Nginx config for ${DOMAIN}..."
cat > "$NGINX_SITE_PATH" <<EOF
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:${N8N_PORT};

        # WebSocket & HTTP/1.1 support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Required proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket and buffering stability
        proxy_cache_bypass \$http_upgrade;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # Optional extra security
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}

server {
    listen 80;
    server_name ${DOMAIN};
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

nginx -t
systemctl reload nginx

# =============================
# UFW (if present)
# =============================
if command -v ufw >/dev/null 2>&1; then
  log "Configuring UFW rules (allow OpenSSH, HTTP, HTTPS)..."
  ufw allow OpenSSH || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

# =============================
# Done
# =============================
log "All set!

- n8n container is running on port ${N8N_PORT}
- Nginx is proxying https://${DOMAIN} -> 127.0.0.1:${N8N_PORT}
- Certificates: /etc/letsencrypt/live/${DOMAIN}/
"
