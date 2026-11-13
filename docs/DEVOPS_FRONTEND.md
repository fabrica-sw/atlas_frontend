# Documentacion DevOps — ATLAS Platform Frontend SPA

**Repositorio:** `https://github.com/eaguilarh01/atlas_frontend.git`
**Organizacion:** EAS Consulting Group
**Version:** 3.0.0
**Runtime de Entrega:** Nginx 1.25 Alpine (`nginx:alpine`)

---

## 1. Resumen de Infraestructura Frontend

El frontend de ATLAS es una Single Page Application (SPA) estatica compuesta por `index.html`, `styles.css` y `favicon.png`. Puede operarse de dos maneras segun el entorno:

1. **Contenedor dedicado (`atlas_frontend`):** Construido desde `Dockerfile` (`nginx:alpine`) sirviendo en el puerto `80` con proxy inverso integrado en `nginx.conf` hacia `http://atlas_backend:54321` para `/auth/`, `/rest/` y `/api/`.
2. **Despliegue unificado On-Premise en Proxmox (`10.10.10.102:/home/eas101/atlas-app/`):** Donde los archivos estaticos se montan en solo lectura dentro de `atlas_backend` (`./index.html:/app/index.html:ro`, `./styles.css:/app/styles.css:ro`, `./favicon.png:/app/favicon.png:ro`) y son expuestos mediante el contenedor `atlas_nginx` en HTTPS (`8443`).

---

## 2. Configuracion Docker y Nginx

### 2.1 Artefactos del Repositorio
- `Dockerfile`: Basado en `nginx:alpine`; reemplaza `/etc/nginx/conf.d/default.conf` con `nginx.conf` y copia `index.html`, `styles.css` y `favicon.png` a `/usr/share/nginx/html/`.
- `nginx.conf`:
  - `try_files $uri $uri/ /index.html;` para enrutamiento SPA sin errores `404`.
  - Compresion Gzip nivel `6` (`text/plain`, `text/css`, `application/json`, `application/javascript`, `image/svg+xml`).
  - `client_max_body_size 50M;` para cargas masivas y adjuntos `.msg`/`.eml`/`.xlsx`.
  - Cabeceras de seguridad: `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `X-XSS-Protection: 1; mode=block`, `Referrer-Policy: strict-origin-when-cross-origin`.
  - Cache estatico de 30 dias (`expires 30d; Cache-Control "public, no-transform"`) sobre CSS/JS/imagenes.
  - Enrutamiento de API: `/auth/`, `/rest/` y `/api/` hacia `http://atlas_backend:54321`.

### 2.2 Construccion y Ejecucion Contenerizada
```bash
# Construir imagen Nginx optimizada
docker build -t atlas-frontend:latest .

# Ejecutar contenedor conectado a la red bridge compartida con el backend
docker run -d \
  --name atlas_frontend \
  --network atlas_network \
  -p 8080:80 \
  --restart unless-stopped \
  atlas-frontend:latest
```

---

## 3. Pipeline de Integracion Continua (CI/CD)

Definido en `.github/workflows/ci.yml`:

- **Disparadores:** `push` y `pull_request` sobre ramas `main` y `master`.
- **Runner:** `ubuntu-latest` con Node.js 20 (`actions/setup-node@v4`).
- **Validacion automatica:**
  ```bash
  node --test tests/frontend-lint.test.js
  ```
- **Regla operativa recomendada pre-despliegue:** Validar adicionalmente todos los bloques `<script>` de `index.html` con `vm.Script` en Node.js para descartar errores de sintaxis antes de copiar a produccion:
  ```bash
  node -e "const fs=require('fs'),vm=require('vm');const html=fs.readFileSync('index.html','utf8');[...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/gi)].forEach(m=>{if(m[1].trim())new vm.Script(m[1]);});console.log('SYNTAX_OK');"
  ```

---

## 4. Procedimiento de Despliegue en Proxmox (`10.10.10.102`)

### 4.1 Transferencia Segura (Bind Mounts Activos)
En el entorno unificado `/home/eas101/atlas-app/`, `index.html`, `styles.css` y `favicon.png` estan montados como volumenes bind (`:ro`) hacia `atlas_backend`.

**Regla critica:** Nunca usar `docker cp` sobre archivos montados con bind mount (genera error `device or resource busy`). Siempre transferir directo al directorio del host y reiniciar el contenedor si aplica:

```bash
# 1. Copiar archivos estaticos actualizados hacia la VM
scp index.html styles.css favicon.png root@10.10.10.102:/home/eas101/atlas-app/

# 2. Validar sintaxis JS en servidor y ejecutar pruebas del frontend
ssh root@10.10.10.102 "cd /home/eas101/atlas-app && node --test frontend-lint.test.js"

# 3. Reiniciar servicios solo si hubo cambios en proxy o servidor Express
ssh root@10.10.10.102 "docker restart atlas_backend atlas_nginx"
```

---

## 5. Verificacion Post-Despliegue y Health Checks

```bash
# 1. Confirmar respuesta HTTP/HTTPS de Nginx y carga del HTML
curl -k -I https://10.10.10.102:8443/

# 2. Confirmar que el proxy reenvia correctamente /api/health
curl -k -s https://10.10.10.102:8443/api/health

# 3. Inspeccionar logs de Nginx ante errores 4xx/5xx
ssh root@10.10.10.102 "docker logs --tail 50 atlas_nginx"
```

---

## 6. Rollback de Emergencia

1. **Via respaldo timestamp (en `/home/eas101/atlas-app/backups/`):**
   ```bash
   cp -a /home/eas101/atlas-app/backups/deploy_<TIMESTAMP>/index.html /home/eas101/atlas-app/
   cp -a /home/eas101/atlas-app/backups/deploy_<TIMESTAMP>/styles.css /home/eas101/atlas-app/
   ```
2. **Via Git:**
   ```bash
   git checkout <commit_estable> -- index.html styles.css nginx.conf
   scp index.html styles.css root@10.10.10.102:/home/eas101/atlas-app/
   ```

---

## 7. Guia Rapida de Troubleshooting Frontend

| Sintoma | Causa Probable | Solucion |
| :--- | :--- | :--- |
| Pantalla en blanco tras despliegue | Error de sintaxis en bloque `<script>` de `index.html` o cache vieja | Validar con `vm.Script` en Node.js y aplicar Hard Reload (`Ctrl+Shift+R`) |
| Error `502 Bad Gateway` en `/rest/` o `/auth/` | Contenedor `atlas_backend` caido o nombre DNS distinto en red Docker | Verificar `docker ps`, salud de `atlas_backend` y red Docker compartida |
| Advertencia de certificado SSL en cliente | CA raiz de EAS no instalada en el equipo cliente | Descargar e instalar `/eas_root_ca.crt` expuesto por `nginx.conf` |
| Fallo al actualizar `index.html` con `docker cp` | El archivo tiene un bind mount `:ro` en `docker-compose.yml` | Sobrescribir directamente `/home/eas101/atlas-app/index.html` via `scp` |
| Error `404` al recargar ruta SPA | Falta directiva `try_files` en Nginx | Confirmar `try_files $uri $uri/ /index.html;` en `nginx.conf` |

