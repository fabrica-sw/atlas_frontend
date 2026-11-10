# Especificacion de Arquitectura Frontend — ATLAS Platform v3.0

## 1. Resumen Ejecutivo
ATLAS Platform es una Single Page Application (SPA) de alta densidad y rendimiento, diseñada para la gestion, supervision tecnica y gobernanza de los 54 sistemas maestros de Coca-Cola FEMSA (KOF) y el control de ventanas de mantenimiento de 1,684 RFCs operacionales.

El frontend opera desacoplado de la logica de persistencia, consumiendo servicios RESTful y de autenticacion provistos por el backend de ATLAS mediante un proxy inverso Nginx de alta disponibilidad.

---

## 2. Topologia de Red y Despliegue

```
[Navegador Cliente (Chrome / Edge / Firefox)]
           │
           │ HTTPS (TLS 1.2/1.3) : Puerto 8443 / 80
           ▼
┌─────────────────────────────────────────────────────────────┐
│  Contenedor Docker: atlas_frontend (Nginx 1.25 Alpine)      │
│  - Entrega de SPA estatica (HTML5, CSS3, JS ES2022)        │
│  - Gzip Compression & Security Headers Hardening            │
│  - SPA Routing Fallback: try_files $uri $uri/ /index.html   │
└──────────────────────────────┬──────────────────────────────┘
                               │
            Proxy Reverso HTTP │ Red Bridge Interna (atlas_network)
            location /rest/    │ Puerto 54321
            location /auth/    │
            location /api/     ▼
┌─────────────────────────────────────────────────────────────┐
│  Contenedor Docker: atlas_backend (Node.js 20 LTS Express)  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Arbol de Componentes y Modulos de Interfaz

La SPA implementa una arquitectura modular orientada a componentes desacoplados montados sobre un shell principal reactivo:

```
App Shell (index.html)
├── Topbar Navigation
│   ├── Breadcrumb y Titulo de Modulo Activo
│   ├── Selector de Modo TQS: [Solo Mi Perfil TQS] vs [Mis Sistemas & Backup]
│   ├── Badges de Alertas SLA y Notificaciones
│   ├── Perfil de Usuario Activo y Logout Seguro
│   └── ATLAS IA Copilot Trigger (Integracion Webhook n8n)
├── Responsive Sidebar Navigation
│   ├── Logo Corporativo ATLAS v3.0 (EAS Consulting Group)
│   ├── Modulos Operativos:
│   │   ├── Dashboard Principal (KPIs, Graficos 3D, Dona de Carga)
│   │   ├── En Ejecucion (Ventana activa, cronometro, bloqueo en caliente)
│   │   ├── Aprobados (Ventanas autorizadas, preparacion de soporte)
│   │   ├── En Espera de VOBO (Checklist tecnico de transportes QAS)
│   │   ├── Finalizados (Historico auditado, metricas de exito)
│   │   ├── Cancelados (Bitacora de motivos, normalizador KOF)
│   │   ├── Alertas Activas (Horizonte 7 dias y deteccion de riesgos)
│   │   └── Solicitudes (Tickets, Incidentes, KITs, RCAs)
│   └── Modulos de Gobernanza (Restringidos a Rol Administrador):
│       ├── Catalogo de Sistemas (54 activos KOF, modal transferencia)
│       ├── Usuarios y Roles (RBAC, reset de claves, auditoria)
│       └── Consola de Auditoria y Logs 360° (Triggers DB PostgreSQL)
└── Main Content Viewport (.main)
    ├── Viewport Clamp: width calc(100vw - 248px)
    ├── Wrappers de Desplazamiento Horizontal (.table-scroll)
    └── Modales Flotantes Reutilizables (VOBO, Transferencia, Drag & Drop)
```

---

## 4. Ciclo de Vida y Gestion de Estado Global

### 4.1 Inicializacion y Rehidratacion
1. Evento `DOMContentLoaded`:
   - Comprobacion de token en almacenamiento local (`sessionStorage.getItem('atlas_token')` con fallback a `localStorage`).
   - Si no existe token valido: Renderizado del `loginOverlay` forzando la autenticacion.
   - Si existe token: Decodificacion del payload JWT (claims `sub`, `email`, `role`, `user_id`) y peticion a `/auth/v1/me`.
2. Hidratacion de Estado Global (`window.state`):
   - `window.state.currentUser`: Objeto del usuario autenticado.
   - `window.state.currentRole`: Rol funcional (`admin`, `director`, `tqs_leader`, `fte`, `guardia`).
   - `window.state.viewMode`: Modo de perspectiva (`isolated` vs `backup`).
   - `window.state.rfcs`: Coleccion local reactiva de cambios.
   - `window.state.sistemas`: Matriz de 54 sistemas KOF.
   - `window.state.solicitudes`: Bandeja de tickets operativos.
   - `window.state.filters`: Criterios activos de fecha (Desde/Hasta), TQS y criticidad.

### 4.2 Desacoplamiento de Titularidad TQS
Para garantizar que ningun especialista visualice cargas ajenas que distorsionen su trabajo:
- `getUserEffectiveSystems(user)`: Consulta unicamente `owner_id = user.id`.
- Los sistemas donde el usuario es suplente se almacenan exclusivamente en `user.sistemas_backup`.
- Funciones de guarda `isRfcOfCurrentUser(rfc)` y `isSolOfCurrentUser(sol)` validan `rfc.owner_id === user.id`. Si el usuario no es titular directo, el registro se excluye de la bandeja activa a menos que se active explicitamente el modo `[Mis Sistemas & Backup]`.

---

## 5. Cliente HTTP e Interceptores (smartFetch)

El cliente HTTP centraliza todas las comunicaciones hacia el backend mediante la utilidad `smartFetch(url, options)`:
- **Inyeccion Automatica de Cabeceras:**
  - `Authorization: Bearer <jwt_token>`
  - `Content-Type: application/json`
  - `apikey: <anon_key>` (compatibilidad con clientes PostgREST)
- **Normalizacion de Rutas REST:**
  - Mapea selectores de PostgREST (`eq.`, `neq.`, `in.`, `order=`, `limit=`) hacia parametros de consulta entendidos por Express.
- **Intercepcion de Respuestas:**
  - `HTTP 401 Unauthorized`: Invalida sesion local, limpia tokens y redirige al overlay de inicio de sesion.
  - `HTTP 403 Forbidden`: Alerta de denegacion de privilegios RBAC sin cerrar la sesion.
  - `HTTP 5xx Server Error`: Despliegue de banner no bloqueante con registro en consola forense.

---

## 6. Seguridad y Manejo de Sesion en Cliente

1. **Almacenamiento de Credenciales:**
   - Cero persistencia de contraseñas en memoria o almacenamiento del navegador.
   - Tokens JWT firmados con algoritmo HMAC-SHA256, vigencia de 8 horas.
2. **Proteccion contra Inyeccion XSS y Manipulacion DOM:**
   - Sanitizacion estricta de cadenas antes de la insercion mediante `escapeXml` y asignacion segura por `textContent`.
3. **Bloqueo de Horarios en Caliente:**
   - La interfaz inhabilita dinamicamente los campos de fecha de inicio, fecha de fin y retorno para cualquier registro cuyo estado sea `En Ejecución`.
   - La politica es reforzada en backend; cualquier intento de manipulacion es rechazado con error 400 y auditado.

---

## 7. Directivas de Produccion Nginx

El archivo `nginx.conf` implementa las siguientes directivas criticas:
- **Fallback SPA:** `try_files $uri $uri/ /index.html;` permite la navegacion directa y refresco de rutas sin emitir errores 404.
- **Compresion Gzip Dinamica:** Nivel de compresion 6 para `text/css`, `application/javascript`, `application/json`, y `image/svg+xml`.
- **Ciberseguridad Hardening:**
  - `X-Frame-Options: SAMEORIGIN` (mitigacion de Clickjacking).
  - `X-Content-Type-Options: nosniff` (mitigacion de sniffing MIME).
  - `Referrer-Policy: strict-origin-when-cross-origin`.
  - `Cache-Control: public, max-age=2592000` para assets estaticos inmutables.

