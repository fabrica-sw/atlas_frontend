# ============================================================
# ATLAS · SAP Operations Suite — Frontend Dockerfile
# EAS Consulting Group
# ============================================================

FROM nginx:alpine

# Reemplazar configuracion por defecto
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar archivos estaticos de la SPA
COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css
COPY favicon.png /usr/share/nginx/html/favicon.png

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

