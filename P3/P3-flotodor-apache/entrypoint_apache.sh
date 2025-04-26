#!/bin/bash

# Función para verificar que existen los certificados
function check_ssl_certs() {
  CERT_KEY="/etc/apache2/ssl/certificado_flotodor.key"
  CERT_CRT="/etc/apache2/ssl/certificado_flotodor.crt"

  # Esperar si los ficheros no existen todavía
  while [ ! -s "$CERT_KEY" ] || [ ! -s "$CERT_CRT" ]; do
    echo "[!] Esperando certificados SSL..."
    sleep 1
  done

  echo "[✓] Certificados SSL encontrados y válidos. Continuando arranque..."
}

# Inicia el script de monitoreo en segundo plano
/usr/local/bin/apache_monitor.sh &

# Inicia Node Exporter en segundo plano
/usr/local/bin/node_exporter &

# --- NUEVO ---
# Espera activa por certificados
check_ssl_certs

# Ahora sí, inicia Apache en primer plano
exec /usr/sbin/apache2ctl -D FOREGROUND
