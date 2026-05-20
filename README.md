# vps-bootstrap

Stack reproducible para WordPress en VPS: **OpenLiteSpeed + PHP 8.2 + MariaDB 11.4 + Redis + LSCache + Let's Encrypt + Backups a B2**.

Diseñado para **AlmaLinux 9** (funciona en Rocky 9). De cero a sitio funcionando en ~15 min.

## Qué incluye

- OpenLiteSpeed (último estable) con HTTP/2 + HTTP/3 (QUIC) + gzip/brotli
- PHP 8.2 con todas las extensiones para WP (gd, mbstring, mysqlnd, imagick, redis, etc.)
- Tuning de PHP: memory_limit 512M, upload 128M, exec time 300s
- MariaDB 11.4 LTS asegurado
- Redis con Unix socket (object cache de WP)
- WordPress instalado vía wp-cli con LSCache + Redis Object Cache activos
- Let's Encrypt con auto-renew + hook a OLS
- fail2ban + firewalld (solo 22/80/443 expuestos)
- Backups diarios a Backblaze B2 vía rclone (3 AM hora local)

## Prerrequisitos

1. **VPS limpio con AlmaLinux 9** y acceso root por SSH
2. **Dominio apuntando al VPS** (si todavía no, puedes correr con `SKIP_SSL=1` y emitir SSL después)
3. **Cuenta Backblaze B2** con bucket y Application Key creados (opcional, puedes saltar backups)

## Uso

### 1) Clonar este template

```bash
git clone https://github.com/TU_USUARIO/vps-bootstrap.git cliente-nuevo
cd cliente-nuevo
```

### 2) Configurar variables del cliente

```bash
cp config.env.example config.env
nano config.env
```

Edita:
- `DOMAIN` — dominio del sitio
- `ADMIN_EMAIL` — para Let's Encrypt + WP admin
- `WP_LOCALE` — `es_CL`, `es_ES`, `en_US`, etc.
- `B2_BUCKET` y `B2_REMOTE_NAME` — para backups (deja vacío para saltar)

### 3) Subir al VPS y ejecutar

```bash
scp -r . root@VPS_IP:/root/vps-bootstrap/
ssh root@VPS_IP "cd /root/vps-bootstrap && bash deploy.sh"
```

### 4) Pasos manuales post-instalación

Ver [`docs/post-install.md`](docs/post-install.md) para:
- Configurar Cloudflare DNS
- Cambiar nameservers en NIC.cl / Namecheap / etc.
- Activar Cloudflare proxy + HSTS

## Scripts

| Script | Qué hace |
|--------|----------|
| `00-bootstrap.sh` | Update + utilidades + hostname + swap |
| `01-hardening.sh` | firewalld + fail2ban |
| `02-openlitespeed.sh` | OLS + PHP 8.2 + extensiones + tuning |
| `03-mariadb-redis.sh` | MariaDB 11.4 asegurada + Redis con socket Unix |
| `04-create-vhost.sh` | docroot, vhost config, listener HTTP |
| `05-install-wordpress.sh` | wp-cli + WP + LSCache + Redis Object Cache |
| `06-ssl.sh` | Let's Encrypt + listener HTTPS + hook renovación |
| `07-backups.sh` | Script de backup + cron diario a B2 |
| `99-final-check.sh` | Verifica que todo esté arriba |

Todos los scripts son **idempotentes** — seguros de re-ejecutar.

## Credenciales

Después del deploy se guardan todas en `/root/vps-bootstrap-credentials.txt`:
- Password admin del OLS WebAdmin
- Password root de MariaDB
- DB de WordPress (nombre, usuario, password)
- Admin de WordPress (URL, usuario, password)

**Pásalas a tu gestor de contraseñas y borra el archivo con `shred -u`.**

## Saltar pasos

En `config.env` puedes setear:
- `SKIP_SSL=1` — no emite cert (cuando DNS aún no propaga)
- `SKIP_BACKUPS=1` — no configura B2

## Licencia

MIT
