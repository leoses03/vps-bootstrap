# Pasos manuales post-instalación

Después de correr `deploy.sh`, completa lo siguiente:

## 1. DNS — Cloudflare

1. Loguéate en https://dash.cloudflare.com
2. **Add a Site** → escribe tu dominio
3. Plan **Free**
4. Cloudflare hace scan del DNS actual. Revisa que importe:
   - MX records de tu correo (Google Workspace, etc.)
   - SPF (TXT `v=spf1 ...`)
   - DKIM (TXT en `google._domainkey` o similar)
   - DMARC (TXT en `_dmarc`)
5. Agrega/edita registros A apuntando al VPS:

| Tipo | Nombre | Contenido | Proxy |
|------|--------|-----------|-------|
| A | @ | IP del VPS | 🟠 Off (gris) por ahora |
| A | www | IP del VPS | 🟠 Off (gris) por ahora |

⚠️ Deja proxy OFF hasta tener SSL configurado en el VPS.

## 2. Cambiar nameservers en el registrar

- NIC.cl, Namecheap, GoDaddy, etc.
- Reemplaza los NS actuales por los 2 que te da Cloudflare (tipo `xxx.ns.cloudflare.com`)
- Espera 1-4 horas (a veces hasta 24h) para que propague

Verifica propagación:
```bash
dig +short NS tudominio.com
dig +short A tudominio.com
```

NS debe mostrar los de Cloudflare. A debe mostrar la IP de tu VPS (con proxy off).

## 3. Emitir SSL (si SKIP_SSL=1 al inicio)

```bash
cd /root/vps-bootstrap
bash scripts/06-ssl.sh
```

## 4. Activar Cloudflare proxy + SSL strict

Una vez SSL OK en el VPS:

- **SSL/TLS → Overview** → modo **Full (strict)** ⚠️ CRÍTICO
- **SSL/TLS → Edge Certificates** → activa **Always Use HTTPS**
- **SSL/TLS → Edge Certificates → HSTS**:
  - Enable HSTS: ON
  - max-age: **6 months** (15552000)
  - includeSubDomains: **OFF** (hasta limpiar subdominios viejos)
  - Preload: **OFF**
  - X-Content-Type-Options: **ON**
- **DNS** → cambia los 🟠 de los A records a "Proxied" (naranja)

## 5. Guardar credenciales y borrar el archivo

```bash
cat /root/vps-bootstrap-credentials.txt
# Pasa todas las pass a tu password manager (1Password, Bitwarden, etc.)
shred -u /root/vps-bootstrap-credentials.txt
```

## 6. (Opcional) SSH key auth

```bash
# En tu PC local
ssh-keygen -t ed25519 -f $HOME\.ssh\cliente_vps

# Copiar al VPS
Get-Content $HOME\.ssh\cliente_vps.pub | ssh root@VPS_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Test
ssh -i $HOME\.ssh\cliente_vps root@VPS_IP

# Si entra sin password → deshabilita password auth en el VPS:
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```

## 7. (Opcional) Notificaciones push con ntfy.sh

Para que el servidor te avise de eventos (SSH login, fail2ban bans, servicios caídos, backup fail, etc.):

1. Instala app **ntfy** en tu celular
2. Suscríbete a un topic único en la app (ej: `cliente-vps-random123`)
3. En el VPS, crea wrapper:

```bash
> /usr/local/bin/notify-ntfy
echo '#!/bin/bash' >> /usr/local/bin/notify-ntfy
echo 'NTFY_TOPIC="TU_TOPIC"' >> /usr/local/bin/notify-ntfy
echo 'TITLE="${1:-VPS}"' >> /usr/local/bin/notify-ntfy
echo 'PRIORITY="${2:-default}"' >> /usr/local/bin/notify-ntfy
echo 'TAGS="${3:-bell}"' >> /usr/local/bin/notify-ntfy
echo 'BODY=$(cat)' >> /usr/local/bin/notify-ntfy
echo 'curl -s -H "Title: $TITLE" -H "Priority: $PRIORITY" -H "Tags: $TAGS" -d "$BODY" "https://ntfy.sh/$NTFY_TOPIC" > /dev/null' >> /usr/local/bin/notify-ntfy
chmod +x /usr/local/bin/notify-ntfy
```

Después puedes integrarlo con fail2ban, cron de servicios, etc. Ver el repo principal de chilenut.cl como ejemplo.

## 8. (Opcional) Updates automáticos del OS

```bash
dnf install -y dnf-automatic
sed -i 's/^upgrade_type = .*/upgrade_type = security/' /etc/dnf/automatic.conf
sed -i 's/^apply_updates = .*/apply_updates = yes/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer
```

Aplica solo parches de seguridad automáticamente (no upgrades de versión).
