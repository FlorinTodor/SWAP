#!/bin/bash

CONTAINER_NAME="${SERVER_NAME:-apache_container}" # Nombre del contenedor que se encuntra en el docker-compose
LOGFILE="/var/log/apache2/apache_monitor_${CONTAINER_NAME}.log" # Ruta del archivo de log que se creará para cada contenedor

while true; do
  echo "[+] Monitoreando Apache en $CONTAINER_NAME - $(date)" >> $LOGFILE # Se añade la fecha y hora al archivo de log

  echo "[*] Procesos Apache:" >> $LOGFILE # Se añade la lista de procesos de Apache al archivo de log
  ps aux | grep apache2 | grep -v grep >> $LOGFILE

  echo "[*] Conexiones activas (netstat):" >> $LOGFILE # Se añade la lista de conexiones activas al archivo de log
  netstat -tuln >> $LOGFILE
  
  echo "[*] Top procesos por uso de memoria:" >> $LOGFILE # Se añade la lista de los 5 procesos con mayor uso de memoria al archivo de log
  ps aux --sort=-%mem | head -n 5 >> $LOGFILE

  echo "----------------------------" >> $LOGFILE
  sleep 30
done
