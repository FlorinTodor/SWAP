#!/bin/bash


# Inicia el script de monitoreo en segundo plano
/usr/local/bin/apache_monitor.sh &

#Iniciamos node exporter en segundo plano
/usr/local/bin/node_exporter &

# Inicia Apache en primer plano
exec /usr/sbin/apache2ctl -D FOREGROUND
