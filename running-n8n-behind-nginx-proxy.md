## Installing Docker on Ubuntu

[Follow this official link](https://docs.docker.com/engine/install/ubuntu/)

## Install Docker compose using below command

```
apt install -y docker-compose
```

## Docker compose to run n8n

```
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
      N8N_HOST: "n8n.successunlock.com"
      N8N_PROTOCOL: "https"
      WEBHOOK_URL: "https://n8n.successunlock.com"

volumes:
  n8n_data:
```


## Command to install Nginx
```
apt-get install -y nginx
```

## Nginx minimum configuration
- minimum nginx configuration to get the certificate
```
server {
    listen 80;
    server_name neightn.successunlock.com;
}
```

## Install certbot with below commands

```
apt-get install -y certbot
apt-get install python3-certbot-nginx
```

- command to get free certificate using certbot
```
sudo certbot --nginx -d neightn.successunlock.com
```


- full nginx configuration
```
server {
    listen 443 ssl;
    server_name n8n.successunlock.com;

    ssl_certificate /etc/letsencrypt/live/<domain.name>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<domain.name>/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:5678;

        # WebSocket & HTTP/1.1 support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Required proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket and buffering stability
        proxy_cache_bypass $http_upgrade;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # (Optional but recommended for extra security)
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}

server {
    listen 80;
    server_name n8n.successunlock.com;

    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
```
