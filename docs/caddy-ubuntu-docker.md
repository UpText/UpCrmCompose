# Caddy On The UpText Ubuntu Host

This guide keeps Caddy outside the `UpCrmCompose` Docker Compose project. The app stack continues to expose:

- UpCRM on host port `8080`
- UpApi on host port `8880`

Caddy runs as a separate Docker container and reverse proxies public traffic to those host ports.

For a workstation install without Caddy, keep `UPCRM_PUBLIC_URL=http://localhost:8080` and start the app from [http://localhost:8080](http://localhost:8080). Use this guide only when the Ubuntu host should serve public HTTPS domains.

## 1. Update The UpCrmCompose Ports

On the Ubuntu host, update the `.env` file in the `UpCrmCompose` directory:

```env
UPCRM_PORT=8080
UPAPI_PORT=8880
UPCRM_PUBLIC_URL=https://crm.example.com
UPAPI_PUBLIC_URL=https://api.example.com
UPAPI_CORS_ALLOWED_ORIGIN_0=https://crm.example.com
UPAPI_CORS_ALLOWED_ORIGIN_1=
UPAPI_CORS_ALLOWED_ORIGIN_2=
```

Replace the two hostnames with the real public DNS names.

Apply the app stack change:

```bash
cd /path/to/UpCrmCompose
docker compose up -d
docker compose ps
```

Confirm the apps answer locally on the host:

```bash
curl -I http://127.0.0.1:8080
curl -I http://127.0.0.1:8880
```

## 2. Create A Caddy Directory

Create a directory outside the compose project:

```bash
sudo mkdir -p /opt/uptext-caddy
cd /opt/uptext-caddy
```

Create `/opt/uptext-caddy/Caddyfile`:

```caddyfile
crm.example.com {
	reverse_proxy host.docker.internal:8080
}

api.example.com {
	reverse_proxy host.docker.internal:8880
}
```

Replace `crm.example.com` and `api.example.com` with the real DNS names.
The `docker run` command below maps `host.docker.internal` to the Ubuntu host gateway.

## 3. Start Caddy

Run Caddy as its own container:

```bash
docker volume create uptext-caddy-data
docker volume create uptext-caddy-config

docker run -d \
  --name uptext-caddy \
  --restart unless-stopped \
  --add-host host.docker.internal:host-gateway \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v /opt/uptext-caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v uptext-caddy-data:/data \
  -v uptext-caddy-config:/config \
  caddy:2
```

Caddy will request and renew HTTPS certificates automatically when public DNS points at the Ubuntu host and inbound ports `80` and `443` are open.

## 4. Verify

Check Caddy status and logs:

```bash
docker ps --filter name=uptext-caddy
docker logs --tail 100 uptext-caddy
```

Then test from another machine:

```bash
curl -I https://crm.example.com
curl -I https://api.example.com/docs
```

## Updating Caddy

After editing `/opt/uptext-caddy/Caddyfile`, reload Caddy without restarting the container:

```bash
docker exec uptext-caddy caddy reload --config /etc/caddy/Caddyfile
```

To upgrade the Caddy image:

```bash
docker pull caddy:2
docker stop uptext-caddy
docker rm uptext-caddy
docker run -d \
  --name uptext-caddy \
  --restart unless-stopped \
  --add-host host.docker.internal:host-gateway \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v /opt/uptext-caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v uptext-caddy-data:/data \
  -v uptext-caddy-config:/config \
  caddy:2
```
