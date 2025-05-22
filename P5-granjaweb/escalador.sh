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
#Limitaciones de escalado
THRESHOLD_UP=50 # CPU alta para escalar, 50%
THRESHOLD_DOWN=20 # CPU baja para desescalar, 20%
MAX_CONTAINERS=20 # Máximo de contenedores
MIN_CONTAINERS=8 # Mínimo de contenedores, las 8 webs iniciales

PROMETHEUS_URL="http://localhost:9090" # URL de Prometheus 
FILE_SD_CONFIG="./file_sd/web_servers.json" # Archivo de configuración de file_sd para Prometheus
STOP_FILE="./stop_escalador.flag" # Archivo de parada para el escalador 

# Método para crear el archivo de log de las acciones del escalador
log() {
  mkdir -p ./logs_escalado
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ./logs_escalado/escalador.log
}

# Método para actualizar la configuración de HAProxy con las instancias activas 
actualizar_haproxy_cfg() {
  local cfg="./P5-flotodor-haproxy/config_balanceador/haproxy.cfg"
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

# Método para actualizar el archivo de configuración de file_sd
# con las instancias activas
# Este archivo es utilizado por Prometheus para descubrir las instancias
# de Node Exporter que están corriendo en los contenedores web.
update_file_sd_config() {
  mapfile -t targets < <(
    get_active_webs | while read w; do
      ip=$(docker inspect -f '{{.NetworkSettings.Networks.red_web.IPAddress}}' "$w")
      printf '%s:9100\n' "$ip"
    done | sort -u
  )

  # crea JSON en un tmp
  tmp=$(mktemp)
  printf '%s\n' "${targets[@]}" |
    jq -Rn '[ inputs | { targets:[.], labels:{job:"node_exporter"} } ]' > "$tmp"

  # mueve sobre el definitivo
  mv "$tmp" "$FILE_SD_CONFIG"
  echo "[i] file_sd actualizado con ${#targets[@]} targets"
}



# Método para obtener los nombres de los contenedores web activos
# y ordenarlos por su índice numérico
get_active_webs() {
  docker ps --format '{{.Names}}' | grep -E "^web[0-9]+$" | sort -V
}

# Método para obtener el siguiente índice disponible para crear una nueva web
# Se basa en los nombres de los contenedores activos
get_next_index() {
  get_active_webs | sed 's/web//' | sort -n | tail -n1 | awk '{print $1 + 1}'
}

# Método para crear una nueva web
# Se basa en el índice pasado como argumento
# Se asigna un tipo de web (nginx o apache) basado en el índice
# Se asigna una IP y un puerto basado en el índice
# Se asignan volúmenes para los logs y el contenido web
# Se conecta la web a las redes red_web y red_servicios
crear_web() {
  local id=$1
  local tipo=$( [ $((id % 2)) -eq 0 ] && echo "nginx" || echo "apache" )
  local puerto=$((8080 + id))
  local ip_web="192.168.10.$((1 + id))"
  local ip_srv="192.168.20.$((1 + id))"

  if [ "$tipo" == "apache" ]; then
    volume1="-v $(pwd)/web_flotodor:/var/www/html"
    volume2="-v $(pwd)/logs_apache:/var/log/apache2"
    imagen="flotodor-apache-image:p5"
  else
    volume1="-v $(pwd)/web_flotodor:/usr/share/nginx/html:ro"
    volume2="-v $(pwd)/logs_nginx:/var/log/nginx"
    imagen="flotodor-nginx_web-image:p5"
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

# Método para eliminar la última web dinámica
# Se basa en el nombre del contenedor y se ordena por su índice numérico
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

# Método para obtener el uso de CPU de los contenedores
# Se basa en la consulta a Prometheus para obtener el uso de CPU
# Se utiliza la métrica node_cpu_seconds_total para calcular el uso de CPU
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


# Método para recargar el balanceador de carga 
recargar_balanceador() {
  if docker ps --format '{{.Names}}' | grep -q "haproxy_balanceador"; then
    docker restart haproxy_balanceador
    echo -e "[↻] Balanceador reiniciado"
    log "[↻] haproxy_balanceador reiniciado"
  fi
}

# BUCLE PRINCIPAL 
# ===========================
# LÓGICA DE BUCLE CON FLAG
# ===========================
rm -f "$STOP_FILE"
echo -e "${greenColour}[i] Escalador iniciado. Esperando señal de parada...${endColour}"


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
  # Comprobar si la consulta fue exitosa y si hay datos
  # Si no hay datos, esperar 15 segundos y volver a intentar
  if [ $? -ne 0 ] || [ -z "$cpu_data" ]; then 
    sleep 15
    continue
  fi

# Obtener el valor de CPU promedio 
  avg_cpu=$(echo "$cpu_data" | awk '{print $2}' | head -n1)
  # Comprobar si el valor de CPU es un número entero
  avg_cpu_int=${avg_cpu%.*}
  # Si no es un número entero, esperar 15 segundos y volver a intentar
  # Esto puede ocurrir si la consulta a Prometheus no devuelve un valor válido
  if ! [[ "$avg_cpu_int" =~ ^[0-9]+$ ]]; then
    sleep 15
    continue
  fi

# Obtener el número total de webs activas
  total_webs=$(get_active_webs | wc -l)
  echo  -e "${blueColour}[i] CPU Promedio: $avg_cpu_int% ${endColour}"

# 
  # Este bloque de código verifica si el promedio de uso de CPU (avg_cpu_int) es mayor o igual al umbral definido (THRESHOLD_UP)
  # y si el número total de contenedores web (total_webs) es menor que el máximo permitido (MAX_CONTAINERS).
  # Si ambas condiciones se cumplen:
  # 1. Obtiene el siguiente índice disponible para un nuevo contenedor web mediante la función get_next_index.
  # 2. Crea un nuevo contenedor web utilizando la función crear_web con el índice obtenido.
  # 3. Actualiza la configuración del balanceador de carga HAProxy llamando a actualizar_haproxy_cfg.
  # 4. Actualiza el archivo de configuración de service discovery llamando a update_file_sd_config.
  # 5. Recarga el balanceador de carga para aplicar los cambios llamando a recargar_balanceador.
  if [ "$avg_cpu_int" -ge "$THRESHOLD_UP" ] && [ "$total_webs" -lt "$MAX_CONTAINERS" ]; then
    index=$(get_next_index)
    crear_web "$index"
    actualizar_haproxy_cfg
    update_file_sd_config
    recargar_balanceador
 
   # 1. Si el uso promedio de CPU es menor que el umbral inferior (THRESHOLD_DOWN) y el número
  #    total de webs es mayor que el mínimo permitido (MIN_CONTAINERS):
  #    - Se elimina el último contenedor web.
  #    - Se actualiza la configuración de HAProxy.
  #    - Se actualiza el archivo de configuración de service discovery.
  #    - Se recarga el balanceador de carga.
  elif [ "$avg_cpu_int" -lt "$THRESHOLD_DOWN" ] && [ "$total_webs" -gt "$MIN_CONTAINERS" ]; then
    eliminar_ultimo_web
    actualizar_haproxy_cfg
    update_file_sd_config
    recargar_balanceador
  # 2. Si el uso promedio de CPU es mayor o igual al umbral superior (THRESHOLD_UP) y el número
  #    total de webs ya ha alcanzado el máximo permitido (MAX_CONTAINERS):
  #    - Se muestra un mensaje indicando que la CPU está alta, pero no se puede escalar más
  #      porque ya se alcanzó el límite máximo de contenedores.
  elif [ "$avg_cpu_int" -ge "$THRESHOLD_UP" ] && [ "$total_webs" -ge "$MAX_CONTAINERS" ]; then
    echo -e "${redColour}[i] CPU alta, pero ya hay $MAX_CONTAINERS webs. No se escala más. ${endColour}"
  # 3. Si el uso promedio de CPU es menor que el umbral inferior (THRESHOLD_DOWN) y el número
  #    total de webs ya está en el mínimo permitido (MIN_CONTAINERS):
  #    - Se muestra un mensaje indicando que la CPU está baja, pero no se puede desescalar más
  #      porque ya se alcanzó el límite mínimo de contenedores.
  elif [ "$avg_cpu_int" -lt "$THRESHOLD_DOWN" ] && [ "$total_webs" -le "$MIN_CONTAINERS" ]; then
    echo -e "${yellowColour}[i] CPU baja, pero ya están las $MIN_CONTAINERS webs mínimas. No se desescala más. ${endColour}"
   # 4. En cualquier otro caso (cuando la CPU está estable y no se cumplen las condiciones
  #    anteriores):
  #    - Se muestra un mensaje indicando que la CPU está estable y no se realizará ninguna
  #      acción de escalado o desescalado.
  else
    echo -e "${turquoiseColour}[i] CPU estable. No se escala ni desescala. ${endColour}"
  fi

  sleep 15
done
