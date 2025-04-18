#!/bin/bash

# Colores
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Configuraciones
THRESHOLD_UP=50
THRESHOLD_DOWN=40
MAX_CONTAINERS=20
MIN_CONTAINERS=8

PROMETHEUS_URL="http://localhost:9090"
FILE_SD_CONFIG="./file_sd/web_servers.json"
STOP_FILE="./stop_escalador.flag"

log() {
  mkdir -p ./logs_escalado
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ./logs_escalado/escalador.log
}

actualizar_haproxy_cfg() {
  local cfg="./P2-flotodor-haproxy/config_balanceador/haproxy.cfg"
  cat > "$cfg" <<EOF
global
    stats socket /var/lib/haproxy/stats

defaults
    mode http
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms
    log global
    option httplog

frontend flotodor
    bind *:80
    default_backend backend_flotodor

backend backend_flotodor
    option httpchk GET /
EOF

  for web in $(get_active_webs); do
    ip=$(docker inspect -f '{{.NetworkSettings.Networks.red_web.IPAddress}}' "$web")
    echo "    server $web $ip:80 maxconn 32 check" >> "$cfg"
  done

  cat >> "$cfg" <<EOF

listen stats
    bind *:9000
    mode http
    stats enable
    stats uri /estadisticas_flotodor
    stats realm HAProxy\\ Statistics
    stats auth flotodor:SWAP1234
EOF
  echo -e "[i] Configuración de HAProxy actualizada con instancias activas"
}

update_file_sd_config() {
  echo "[" > "$FILE_SD_CONFIG"
  echo "  {" >> "$FILE_SD_CONFIG"
  echo '    "targets": [' >> "$FILE_SD_CONFIG"
  for web in $(get_active_webs); do
    ip=$(docker inspect -f '{{.NetworkSettings.Networks.red_web.IPAddress}}' "$web")
    echo "      \"$ip:9100\"," >> "$FILE_SD_CONFIG"
  done
  sed -i '$ s/,$//' "$FILE_SD_CONFIG"
  echo "    ]," >> "$FILE_SD_CONFIG"
  echo '    "labels": { "job": "node_exporter" }' >> "$FILE_SD_CONFIG"
  echo "  }" >> "$FILE_SD_CONFIG"
  echo "]" >> "$FILE_SD_CONFIG"
  echo -e "[i] Archivo file_sd actualizado con targets activos"
}

get_active_webs() {
  docker ps --format '{{.Names}}' | grep -E "^web[0-9]+$" | sort -V
}

get_next_index() {
  get_active_webs | sed 's/web//' | sort -n | tail -n1 | awk '{print $1 + 1}'
}

crear_web() {
  local id=$1
  local tipo=$( [ $((id % 2)) -eq 0 ] && echo "nginx" || echo "apache" )
  local puerto=$((8080 + id))
  local ip_web="192.168.10.$((1 + id))"
  local ip_srv="192.168.20.$((1 + id))"

  if [ "$tipo" == "apache" ]; then
    volume1="-v $(pwd)/web_flotodor:/var/www/html"
    volume2="-v $(pwd)/logs_apache:/var/log/apache2"
    imagen="flotodor-apache-image:p2"
  else
    volume1="-v $(pwd)/web_flotodor:/usr/share/nginx/html:ro"
    volume2="-v $(pwd)/logs_nginx:/var/log/nginx"
    imagen="flotodor-nginx_web-image:p2"
  fi

  docker network disconnect red_web "web$id" 2>/dev/null
  docker network disconnect red_servicios "web$id" 2>/dev/null

  docker run -d --name "web$id" \
    --network red_web \
    --ip "$ip_web" \
    -e SERVER_NAME=web$id \
    $volume1 \
    $volume2 \
    -p "$puerto:80" \
    "$imagen"

  docker network connect --ip "$ip_srv" red_servicios "web$id"
  echo -e "[+] web$id (${tipo}) creado y arrancado"
  log "[+] web$id creado"
}

eliminar_ultimo_web() {
  last_web=$(get_active_webs | grep -E '^web([9-9]|[1-9][0-9]+)$' | sort -V | tail -n 1)
  if [ ! -z "$last_web" ]; then
    docker stop "$last_web" && docker rm "$last_web"
    echo -e "[↓] $last_web eliminado (dinámica)"
    log "[↓] $last_web eliminado (dinámica)"
  else
    echo "[i] No hay webs dinámicas por encima de web8 para eliminar"
    log "[i] No hay webs dinámicas por encima de web8 para eliminar"
  fi
}

get_cpu_usage() {
  local response
  response=$(curl -sG "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode 'query=100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)')

  if echo "$response" | jq -e '.data.result | length > 0' &>/dev/null; then
    echo "$response" | jq -r '.data.result[] | "\(.metric.instance) \(.value[1])"'
    return 0
  else
    return 1
  fi
}



recargar_balanceador() {
  if docker ps --format '{{.Names}}' | grep -q "haproxy_balanceador"; then
    docker restart haproxy_balanceador
    echo -e "[↻] Balanceador reiniciado"
    log "[↻] haproxy_balanceador reiniciado"
  fi
}

# ===========================
# LÓGICA DE BUCLE CON FLAG
# ===========================
rm -f "$STOP_FILE"
echo -e "{colorGreen}[i] Escalador iniciado. Esperando señal de parada...{resetColor}"

# ================================
# Esperar hasta obtener un valor de CPU válido, esto se debe a que
# el contenedor de Prometheus puede tardar un poco en iniciar y
# devolver métricas válidas.
# ================================
while true; do
  # Comprobar si hay señal de parada
  if [[ -f "$STOP_FILE" ]]; then
    echo "[i] Señal de parada detectada. Deteniendo escalador..."
    log "[!] Señal de parada detectada. Deteniendo escalador..."
    rm -f "$STOP_FILE"
    exit 0
  fi

  # Obtener datos de CPU
  cpu_data=$(get_cpu_usage)
  if [ $? -ne 0 ] || [ -z "$cpu_data" ]; then
    sleep 15
    continue
  fi

  avg_cpu=$(echo "$cpu_data" | awk '{print $2}' | head -n1)
  avg_cpu_int=${avg_cpu%.*}
  if ! [[ "$avg_cpu_int" =~ ^[0-9]+$ ]]; then
    sleep 15
    continue
  fi

  total_webs=$(get_active_webs | wc -l)
  echo "[i] CPU Promedio: $avg_cpu_int%"

  if [ "$avg_cpu_int" -ge "$THRESHOLD_UP" ] && [ "$total_webs" -lt "$MAX_CONTAINERS" ]; then
    index=$(get_next_index)
    crear_web "$index"
    actualizar_haproxy_cfg
    update_file_sd_config
    recargar_balanceador
  elif [ "$avg_cpu_int" -lt "$THRESHOLD_DOWN" ] && [ "$total_webs" -gt "$MIN_CONTAINERS" ]; then
    eliminar_ultimo_web
    actualizar_haproxy_cfg
    update_file_sd_config
    recargar_balanceador
  elif [ "$avg_cpu_int" -ge "$THRESHOLD_UP" ] && [ "$total_webs" -ge "$MAX_CONTAINERS" ]; then
    echo "[i] CPU alta, pero ya hay $MAX_CONTAINERS webs. No se escala más."
  elif [ "$avg_cpu_int" -lt "$THRESHOLD_DOWN" ] && [ "$total_webs" -le "$MIN_CONTAINERS" ]; then
    echo "[i] CPU baja, pero ya están las $MIN_CONTAINERS webs mínimas. No se desescala más."
  else
    echo "[i] CPU estable. No se escala ni desescala."
  fi

  sleep 15
done