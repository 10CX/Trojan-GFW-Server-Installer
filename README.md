# Trojan-GFW-Server-Installer

```sh
bash <(curl -sSL https://raw.githubusercontent.com/10CX/Trojan-GFW-Server-Installer/main/install-trojan.sh) --domain example.com --password "ChangeMe"
```

---

## PREREQUISITES

- Debian 12 or newer, running as **root** (or via `sudo`).  
- **Ports 80 & 443** open to the Internet.  
- The specified domain’s **DNS** already points to this server.  

---

## USAGE

```sh
install-trojan.sh -d <domain> -p <password> [options]
```

---

## OPTIONS

| Flag | Long flag | Description |
|------|-----------|-------------|
| `-d` | `--domain`   | FQDN that already resolves to this server |
| `-p` | `--password` | Primary Trojan password (no spaces)       |
| `-e` | `--email`    | E-mail for Let’s Encrypt registration     |
| `-h` | `--help`     | Show this help and exit                   |

---

## WHAT THIS SCRIPT DOES

1. Updates **apt** & installs *nginx*, *certbot* and *trojan*.  
2. Creates a minimal **nginx** vhost listening **only** on port 80 (`/var/www/html`).  
3. Obtains a **Let’s Encrypt** certificate via webroot.  
4. Writes `/etc/trojan/config.json` using your **domain** & **password**.  
5. Enables and starts `trojan.service` (listening on 443).  

---

## REFERENCES

<https://oilandfish.net/posts/quickly-set-up-trojan-gfw.html>
