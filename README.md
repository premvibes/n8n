# 🚀 Single Script to Install n8n on Ubuntu

This repository provides a **one-command installer** that sets up a fully working [n8n](https://n8n.io) instance on Ubuntu — including **Docker**, **Nginx**, **SSL (Let's Encrypt)**, and all necessary dependencies.

---

## 🧩 Features

* Installs Docker & Docker Compose automatically
* Deploys the official **n8n** Docker container (`docker.n8n.io/n8nio/n8n:latest`)
* Configures **Nginx reverse proxy** with HTTPS
* Automatically obtains and installs an SSL certificate via **Certbot**
* Fully configurable through environment variables
* Persistent data stored in `/var/lib/docker/volumes/n8n_data/_data`

---

## 📥 Download the Script

Run this command on your Ubuntu server to download the installer:

```bash
wget https://raw.githubusercontent.com/learnwithvikasjha/n8n/refs/heads/main/install-n8n.sh
```

---

## ⚙️ Run the Installer

Use the following command to run the script with your own domain and email address:

```bash
sudo -E DOMAIN="<your-domain-or-subdomain>" EMAIL="<your-email-id>" bash install-n8n.sh
```

**Example:**

```bash
sudo -E DOMAIN="n8n.gobotify.com" EMAIL="admin@gobotify.com" bash install-n8n.sh
```

---

## 🗂️ Installation Details

| Component              | Location                                 | Description                                                  |
| ---------------------- | ---------------------------------------- | ------------------------------------------------------------ |
| **n8n Docker project** | `/opt/n8n`                               | Contains the `docker-compose.yml` and manages the container. |
| **Persistent data**    | `/var/lib/docker/volumes/n8n_data/_data` | Stores workflows, credentials, and user data.                |
| **Nginx config**       | `/etc/nginx/sites-available/n8n`         | Reverse proxy for HTTPS access.                              |
| **SSL certificates**   | `/etc/letsencrypt/live/<your-domain>/`   | Managed by Certbot.                                          |

---

## 🔧 Useful Commands

```bash
# Check n8n container status
docker compose -f /opt/n8n/docker-compose.yml ps

# View logs
docker compose -f /opt/n8n/docker-compose.yml logs -f

# Restart n8n
docker compose -f /opt/n8n/docker-compose.yml restart
```

---

## ✅ After Installation

Once the script completes:

1. Visit your instance at `https://<your-domain>`.
2. Create your n8n account and start automating!

---

## 🧠 Notes

* Works on **Ubuntu 20.04+** (tested on 22.04 and 24.04).
* Ensure your domain DNS `A` record points to the server’s public IP **before running the script**.
* If you rerun the script with a different domain, it will automatically reconfigure Nginx and Certbot.

---

## 🪄 Author

Created by **[Vikas Jha](https://github.com/learnwithvikasjha)**
