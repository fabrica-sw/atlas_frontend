# ATLAS Platform — Frontend SPA

Cliente web oficial de **ATLAS Platform v3.0** (Operaciones SAP Coca-Cola FEMSA).
Arquitectura Single Page Application (SPA) de alta densidad y rendimiento para el control transaccional de ventanas de cambio (RFCs), aprobaciones técnicas (VOBO), auditoría y observabilidad de 54 sistemas maestros.

- **Repositorio Oficial:** [https://github.com/eaguilarh01/atlas_frontend.git](https://github.com/eaguilarh01/atlas_frontend.git)
- **Organización:** EAS Consulting Group
- **Versión:** 3.0.0
- **Stack Tecnológico:** HTML5, CSS3 Nativo (Variables de Tema y Viewport Clamp), JavaScript ES2022, SheetJS, Lucide, Nginx 1.25 Alpine

---

## 1. Documentación Técnica de Entrega (docs/)

La especificación completa del sistema, diagramas editables y manuales oficiales compilados se encuentran en la carpeta `docs/`:

- **Especificación de Arquitectura (PDF):** [`docs/ARQUITECTURA_FRONTEND.pdf`](docs/ARQUITECTURA_FRONTEND.pdf)
- **Especificación de Arquitectura (Markdown):** [`docs/ARQUITECTURA_FRONTEND.md`](docs/ARQUITECTURA_FRONTEND.md)
- **Diagrama de Arquitectura Oficial (Draw.io / Diagrams.net):** [`docs/diagrama_arquitectura.drawio`](docs/diagrama_arquitectura.drawio)
- **Diagrama del Proyecto Frontend (Draw.io / Diagrams.net):** [`docs/diagrama_proyecto_frontend.drawio`](docs/diagrama_proyecto_frontend.drawio)
- **Documentación DevOps Frontend (PDF):** [`docs/DEVOPS_FRONTEND.pdf`](docs/DEVOPS_FRONTEND.pdf)
- **Documentación DevOps Frontend (Markdown):** [`docs/DEVOPS_FRONTEND.md`](docs/DEVOPS_FRONTEND.md)
- **Memoria Técnica del Proyecto ATLAS (PDF):** [`docs/MEMORIA_TECNICA_PROYECTO_ATLAS_SAP.pdf`](docs/MEMORIA_TECNICA_PROYECTO_ATLAS_SAP.pdf)
- **Manual Operativo - Administrador (PDF):** [`docs/Manual_Operativo_ATLAS_Administrador.pdf`](docs/Manual_Operativo_ATLAS_Administrador.pdf)
- **Manual Operativo - Líder Técnico TQS (PDF):** [`docs/Manual_Operativo_ATLAS_TQS_Leader.pdf`](docs/Manual_Operativo_ATLAS_TQS_Leader.pdf)
- **Manual Operativo - Dirección Ejecutiva (PDF):** [`docs/Manual_Operativo_ATLAS_Direccion.pdf`](docs/Manual_Operativo_ATLAS_Direccion.pdf)

---

## 2. Estructura del Repositorio

```text
atlas-frontend/
├── index.html                  # Núcleo SPA (Vistas, componentes y controladores reactivos)
├── styles.css                  # Sistema de diseño, layout responsive y temas
├── favicon.png                 # Icono oficial corporativo
├── nginx.conf                  # Configuración Nginx de producción con proxy pass y fallback SPA
├── Dockerfile                  # Contenedor optimizado Nginx Alpine
├── package.json                # Definición de paquete y scripts de testing
├── .gitignore                  # Exclusiones de seguridad (documentación explícita permitida)
├── docs/                       # Paquete de entrega técnica (Arquitectura, Draw.io y PDFs)
│   ├── ARQUITECTURA_FRONTEND.pdf
│   ├── ARQUITECTURA_FRONTEND.md
│   ├── diagrama_arquitectura.drawio
│   ├── MEMORIA_TECNICA_PROYECTO_ATLAS_SAP.pdf
│   ├── Manual_Operativo_ATLAS_Administrador.pdf
│   ├── Manual_Operativo_ATLAS_TQS_Leader.pdf
│   └── Manual_Operativo_ATLAS_Direccion.pdf
├── tests/
│   └── frontend-lint.test.js   # Suite automatizada de integridad DOM y atributos
└── .github/
    └── workflows/
        └── ci.yml              # Pipeline de integración continua (CI)
```

---

## 3. Ejecución en Entorno Local

Para servir la aplicación estática localmente:

```bash
# Opción 1: Servidor Node.js
npx serve . -p 8080

# Opción 2: Python 3
python -m http.server 8080
```

Acceda a `http://localhost:8080` en su navegador.

---

## 4. Pruebas Automatizadas

Ejecute la suite de pruebas que valida sintaxis, selectores DOM, modales y consistencia de atributos:

```bash
npm test
```

---

## 5. Compilación y Despliegue con Docker

### 5.1 Construcción de la Imagen Docker
```bash
docker build -t atlas-frontend:latest .
```

### 5.2 Ejecución del Contenedor
```bash
docker run -d \
  --name atlas_frontend \
  -p 8080:80 \
  --restart unless-stopped \
  atlas-frontend:latest
```

El servidor Nginx entregará los recursos estáticos y enrutará las peticiones `/rest/*`, `/auth/*` y `/api/*` hacia el contenedor backend en la red compartida.
