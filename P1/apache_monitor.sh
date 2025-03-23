#!/bin/bash

CONTAINER_NAME="${SERVER_NAME:-apache_container}"
LOGFILE="/var/log/apache2/apache_monitor_${CONTAINER_NAME}.log"

while true; do
  echo "[+] Monitoreando Apache en $CONTAINER_NAME - $(date)" >> $LOGFILE
  echo "[+] Estado de Apache - $(date)" >> $LOGFILE

  echo "[*] Procesos Apache:" >> $LOGFILE
  ps aux | grep apache2 | grep -v grep >> $LOGFILE

  echo "[*] Conexiones activas (netstat):" >> $LOGFILE
  netstat -tuln >> $LOGFILE

  echo "[*] Estado de Apache (apache2ctl):" >> $LOGFILE
  apache2ctl status >> $LOGFILE 2>> $LOGFILE

  echo "[*] Top procesos por uso de memoria:" >> $LOGFILE
  ps aux --sort=-%mem | head -n 5 >> $LOGFILE

  echo "----------------------------" >> $LOGFILE
  sleep 30
done
