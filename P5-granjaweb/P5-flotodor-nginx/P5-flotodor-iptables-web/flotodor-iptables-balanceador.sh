#!/bin/bash

BALANCER_IP="192.168.10.50"

### POLÍTICAS POR DEFECTO ###
iptables -P INPUT  DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

### ESTADO Y LOOPBACK ###
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

### FLAGS TCP INVÁLIDOS ###
iptables -A INPUT -p tcp --tcp-flags ALL NONE        -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL         -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,FIN     -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST     -j DROP


### CADENA DE RATE LIMITING ###
iptables -F RATE_HTTP 2>/dev/null || iptables -N RATE_HTTP

# Límite general 3 req/s con ráfaga de 3
iptables -A RATE_HTTP -m limit --limit 3/second --limit-burst 3 -j RETURN

# Protección específica por IP
for SRC in 127.0.0.1 $BALANCER_IP 172.17.0.1; do
  for PORT in 80 443; do
    iptables -A RATE_HTTP -p tcp -s $SRC --dport $PORT \
      -m recent --name LOCALRATE --update --seconds 30 --hitcount 5 --rttl \
      -j LOG --log-prefix "[RATE_$SRC] "
    iptables -A RATE_HTTP -p tcp -s $SRC --dport $PORT \
      -m recent --name LOCALRATE --update --seconds 30 --hitcount 5 --rttl -j DROP
    iptables -A RATE_HTTP -p tcp -s $SRC --dport $PORT \
      -m recent --name LOCALRATE --set
  done
done

iptables -A RATE_HTTP -j LOG --log-prefix "[HTTP_RATE_DROP] "
iptables -A RATE_HTTP -j DROP

# ENLACE desde INPUT
iptables -I INPUT -p tcp --dport 80  -j RATE_HTTP
iptables -I INPUT -p tcp --dport 443 -j RATE_HTTP

### FILTROS SQLi y XSS ###
for STRING in "SELECT " "UNION SELECT" "' OR 1=1"; do
  iptables -A INPUT -p tcp --dport 80 -m string --algo bm --string "$STRING" -j DROP
  iptables -A INPUT -p tcp --dport 443 -m string --algo bm --string "$STRING" -j DROP
done

for PORT in 80 443; do
  for STRING in "<script>" "%3Cscript%3E" "onerror=" "alert(" "%3Cimg%20src=x%20onerror="; do
    iptables -A INPUT -p tcp --dport $PORT -m string --algo bm --string "$STRING" -j DROP
  done
done

### LÍMITE BÁSICO DE SYN FLOOD ###
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

### MITIGACIÓN DE CONEXIONES EXCESIVAS POR IP ###
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP

### LIMITAR FRECUENCIA DE NUEVAS CONEXIONES POR IP (hashlimit) ###
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m hashlimit --hashlimit 3/sec --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name http_limit -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j DROP

iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m hashlimit --hashlimit 3/sec --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name https_limit -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j DROP

### PUERTOS PERMITIDOS ###
for PORT in 80 443 9100 2049 111; do
  iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
done

iptables -A INPUT -p tcp --dport 8081:8088 -j ACCEPT

### BLOQUEO DE RANGOS NO USADOS ###
iptables -A INPUT -p tcp --dport 0:79       -j DROP
iptables -A INPUT -p tcp --dport 81:109     -j DROP
iptables -A INPUT -p tcp --dport 113:442    -j DROP
iptables -A INPUT -p tcp --dport 444:1023   -j DROP
iptables -A INPUT -p tcp --dport 1025:65535 -j DROP

echo "[✓] IPTABLES cargado con refuerzo hashlimit y connlimit por IP."
a