#!/usr/bin/env bash
#
# install-trojan.sh – Trojan-GFW server installer for Debian 12+
#
#  ▸ Installs & configures nginx (port 80), Let’s Encrypt certs and Trojan (port 443)
#  ▸ Requires a DNS A/AAAA record for the supplied domain pointing to this host
#
set -euo pipefail

### ────────────────────────────── CLI & HELP ────────────────────────────── ###
usage() {
cat <<'EOF'
Trojan-GFW Installer for Debian 12+

USAGE:
  install-trojan.sh -d <domain> -p <password> [options]

OPTIONS:
  -d, --domain   FQDN that already resolves to this server (required)
  -p, --password Primary Trojan password (required, no spaces)
  -e, --email    E-mail for Let's Encrypt registration (default: none)
  -h, --help     Show this help and exit

WHAT THIS SCRIPT DOES:
  1. Updates apt & installs nginx, certbot and trojan.
  2. Creates a minimal nginx vhost listening ONLY on port 80 (/var/www/html).
  3. Obtains a Let’s Encrypt certificate via webroot.
  4. Writes /etc/trojan/config.json using your domain & password.
  5. Enables and starts trojan.service (listening on 443).

PREREQUISITES:
  * Debian 12 or newer, running as root (or sudo).
  * Ports 80 & 443 open to the Internet.
  * The specified domain’s DNS already points here.

EXAMPLE:
  sudo ./install-trojan.sh --domain example.com --password "S3cr3t!" --email admin@example.com
EOF
}

DOMAIN=""
PASSWORD=""
EMAIL=""

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain)   DOMAIN="$2";   shift 2 ;;
    -p|--password) PASSWORD="$2"; shift 2 ;;
    -e|--email)    EMAIL="$2";    shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$DOMAIN" || -z "$PASSWORD" ]] && { echo "Error: --domain and --password are required."; usage; exit 1; }

### ────────────────────────────── SETUP ─────────────────────────────────── ###
echo ">>> Updating system & installing packages..."
apt update -y
apt install -y nginx certbot python3-certbot-nginx trojan curl wget unzip zip

echo ">>> Creating simple web root..."
cd /tmp
wget https://github.com/arcdetri/sample-blog/archive/master.zip
unzip master.zip
cp -r sample-blog-master/html/* /var/www/html/
cd
chown -R www-data:www-data /var/www/html

echo ">>> Configuring nginx (port 80 only)..."
VHOST="/etc/nginx/sites-available/default"
cat > "$VHOST" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name $DOMAIN;
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
ln -sf "$VHOST" /etc/nginx/sites-enabled/

sed -i '/listen .*443/d' /etc/nginx/sites-enabled/* || true

systemctl enable nginx
nginx -t && systemctl reload nginx

echo ">>> Requesting Let's Encrypt certificate..."
WEBROOT="/var/www/html"
if [[ -n "$EMAIL" ]]; then
  certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" -m "$EMAIL" --agree-tos -n
else
  certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" --register-unsafely-without-email --agree-tos -n
fi

echo ">>> Setting certificate permissions for Trojan..."
chmod -R o+rx /etc/letsencrypt

echo ">>> Writing /etc/trojan/config.json ..."
cat > /etc/trojan/config.json <<EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": ["$PASSWORD"],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem",
        "key": "/etc/letsencrypt/live/$DOMAIN/privkey.pem",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 80
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOF

echo ">>> Enabling & starting trojan.service ..."
systemctl enable trojan
systemctl restart trojan

sleep 2
if systemctl is-active --quiet trojan; then
  echo ">>> SUCCESS! Trojan is running."
else
  echo "ERROR: Trojan failed to start. Check logs with: journalctl -u trojan -xe"
  exit 1
fi
