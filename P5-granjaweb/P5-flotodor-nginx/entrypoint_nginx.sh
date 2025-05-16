#!/bin/bash
# SCRIPT PARA PODER EJECUTAR LOS DOS SERVICIOS EN SEGUNDO PLANO, ya que con el cmd solo se puede uno y no permite &&

# Comprobamos la configuración de Nginx para evitar bucles infinitos
nginx -t
if [ $? -ne 0 ]; then
  echo "❌ Error en la configuración de Nginx. Abortando."
  exit 1
fi

# Iniciamos PHP-FPM en segundo plano
php-fpm8.3 --nodaemonize &

# Iniciamos el scirpt de IPTABLES en segundo plano
/usr/local/bin/iptables.sh &


# Iniciamos el node exporter en segundo plano
/usr/local/bin/node_exporter &

# Arrancamos Nginx en primer plano
nginx -g "daemon off;"



