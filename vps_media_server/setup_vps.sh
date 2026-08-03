#!/bin/bash
set -e

APP_DIR="/opt/stayfix-media"
NODE_VERSION="20"
DOMAIN="media.stayfix.co"

echo "========================================"
echo " Stayfix Media Server — VPS Setup"
echo "========================================"

# ── 1. System updates ────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install Node.js 20 LTS ────────────────────────────────────
echo "[2/8] Installing Node.js ${NODE_VERSION}..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - >/dev/null 2>&1
apt-get install -y -qq nodejs

echo "Node: $(node -v)  NPM: $(npm -v)"

# ── 3. Install PM2 ───────────────────────────────────────────────
echo "[3/8] Installing PM2..."
npm install -g pm2 --silent
pm2 --version

# ── 4. Install Nginx + Certbot ───────────────────────────────────
echo "[4/8] Installing Nginx and Certbot..."
apt-get install -y -qq nginx certbot python3-certbot-nginx ufw

# ── 5. Create app directory ──────────────────────────────────────
echo "[5/8] Setting up app directory at ${APP_DIR}..."
mkdir -p "${APP_DIR}/storage/media"
mkdir -p "${APP_DIR}/storage/meta"
mkdir -p "${APP_DIR}/src"

# ── 6. Firewall ──────────────────────────────────────────────────
echo "[6/8] Configuring firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
echo "Firewall status:"
ufw status

# ── 7. Configure Nginx ───────────────────────────────────────────
echo "[7/8] Configuring Nginx for ${DOMAIN}..."
cat > /etc/nginx/sites-available/stayfix-media << 'NGINX_EOF'
server {
    listen 80;
    server_name media.stayfix.co;

    client_max_body_size 25M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/stayfix-media /etc/nginx/sites-enabled/stayfix-media
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

echo "Nginx configured OK."

# ── 8. PM2 startup ───────────────────────────────────────────────
echo "[8/8] Setting up PM2 startup..."
pm2 startup systemd -u root --hp /root | tail -1 | bash || true
systemctl enable pm2-root 2>/dev/null || true

echo ""
echo "========================================"
echo " Base setup COMPLETE!"
echo " Next: upload app files, run npm install,"
echo " then: pm2 start src/server.js --name stayfix-media"
echo "========================================"
