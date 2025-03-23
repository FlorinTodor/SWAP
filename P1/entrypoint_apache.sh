#!/bin/bash


# Inicia el script de monitoreo en segundo plano
/usr/local/bin/apache_monitor.sh &

# Inicia Apache en primer plano
exec /usr/sbin/apache2ctl -D FOREGROUND
