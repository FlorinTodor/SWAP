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

trap ctrl_c INT
# Función para manejar la señal de interrupción (Ctrl+C)
function ctrl_c(){
  echo -e "\n ${redColour}[!] Saliendo....${endColour}"
}

# Función para mostrar el panel de ayuda
function helpPanel(){
  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Uso:${endColour}\n"
  echo -e "\t${purpleColour}-c${endColour}${grayColour} Limpiar archivos dentro de logs_apache y logs_nginx${endColour}"
  echo -e "\t${purpleColour}-s${endColour}${grayColour} Detener y eliminar contenedores (apache/nginx/nginx_balanceador/haproxy_balanceador/all)${endColour}"
  echo -e "\t${purpleColour}-b${endColour}${grayColour} Crear imagen docker (apache/nginx/nginx_balanceador/haproxy_balanceador/all)${endColour}"
  echo -e "\t${purpleColour}-u${endColour}${grayColour} Ejecutar docker compose up para el balanceador (nginx/haproxy/traefik/envoy/escalado)${endColour}"
  echo -e "\t\t${grayColour}Puedes indicar una estrategia de balanceo para los siguientes balanceadores:${endColour}"
  echo -e "\t\t${turquoiseColour}nginx:${endColour}"
  echo -e "\t\t   ${greenColour}pd${endColour}${grayColour} = ponderación con pesos${endColour}"
  echo -e "\t\t   ${greenColour}rb${endColour}${grayColour} = round-robin (por defecto)${endColour}"
  echo -e "\t\t${turquoiseColour}haproxy:${endColour}"
  echo -e "\t\t   ${greenColour}lc${endColour}${grayColour} = menor número de conexiones${endColour}"
  echo -e "\t\t   ${greenColour}rb${endColour}${grayColour} = round-robin (por defecto)${endColour}"
  echo -e "\t\t${turquoiseColour}traefik/envoy:${endColour} ${greenColour}sin parámetro ${endColour}${grayColour} = round-robin (por defecto)${endColour}"
  echo -e "\t\t${turquoiseColour}escalado:${endColour} ${greenColour}sin parámetro ${endColour}${grayColour} = round-robin (por defecto)${endColour}"
  echo -e "\t${purpleColour}-p${endColour}${grayColour} Actualizar paquetes dentro de los contenedores activos${endColour}"
  echo -e "\t${purpleColour}-h${endColour}${grayColour} Mostrar este panel de ayuda${endColour}\n"
}



# Función para detener y eliminar contenedores
# Se detienen y eliminan los contenedores especificados en la variable containers
function stop_and_remove() {
  local type=$1
  local containers=""

  case $type in
    apache)
      containers=$(docker ps -a --format '{{.Names}}' | grep '^web[0-9]*$' | xargs -n1 docker inspect --format '{{.Name}} {{.Config.Image}}' 2>/dev/null | grep 'apache' | cut -d' ' -f1 | sed 's/^\/\(.*\)/\1/')
      ;;
    nginx)
      containers=$(docker ps -a --format '{{.Names}}' | grep '^web[0-9]*$' | xargs -n1 docker inspect --format '{{.Name}} {{.Config.Image}}' 2>/dev/null | grep 'nginx' | cut -d' ' -f1 | sed 's/^\/\(.*\)/\1/')
      ;;
    haproxy_balanceador)
      containers="haproxy_balanceador"
      ;;
    nginx_balanceador)
      containers="nginx_balanceador"
      ;;
    traefik_balanceador)
      containers="traefik_balanceador"
      ;;
    envoy_balanceador)
      containers="envoy_balanceador"
      ;;
    escalado)
      containers="grafana prometheus node-exporter"
      ;;
    all)
      containers=$(docker ps -a --format '{{.Names}}' | grep -E '^(web[0-9]+|grafana|prometheus|node-exporter|.*_balanceador)$')
      ;;
    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx, nginx_balanceador, haproxy_balanceador, traefik_balanceador, envoy_balanceador, escalado o all${endColour}"
      return
      ;;
  esac

  local existing=()
  for name in $containers; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
      existing+=("$name")
    fi
  done

  if [ ${#existing[@]} -eq 0 ]; then
    echo -e "${yellowColour}[!] No se encontraron contenedores activos para eliminar.${endColour}"
  else
    docker stop "${existing[@]}" &>/dev/null
    docker rm -f "${existing[@]}" &>/dev/null
    for name in "${existing[@]}"; do
      echo -e "${greenColour}[+] Contenedor ${name} detenido y eliminado${endColour}"
    done
  fi

  # Crear el archivo de parada si se eliminan servicios relacionados
  if [[ "$type" == "escalado" || "$type" == "all" ]]; then
    touch stop_escalador.flag
    echo -e "${blueColour}[i] Escalador detenido (flag creada)${endColour}"
  fi
}


# Función para construir imágenes Docker
# Se eliminan las imágenes existentes y se construyen nuevas imágenes según el tipo especificado
# Las imágenes disponibles son: apache, nginx y haproxy
function build_image(){
  case $1 in
    apache)
      docker rmi flotodor-apache-image:p5 -f
      docker build --no-cache -t flotodor-apache-image:p5 -f ./P5-flotodor-apache/DockerfileApache_florin .
      ;;
    nginx)
      docker rmi flotodor-nginx_web-image:p5 -f
      docker build --no-cache -t flotodor-nginx_web-image:p5 -f ./P5-flotodor-nginx/DockerfileNginx_web .
      ;;
    nginx_balanceador)
      docker rmi flotodor-nginx_balanceador-image:p5 -f
      docker build --no-cache  -t flotodor-nginx_balanceador-image:p5 -f ./P5-flotodor-nginx/DockerfileNginx_balanceador .
      ;;
    haproxy_balanceador)
      docker rmi flotodor-haproxy_balanceador-image:p5 -f
      docker build --no-cache -t flotodor-haproxy_balanceador-image:p5 -f ./P5-flotodor-haproxy/DockerfileHAproxy_balanceador .
      ;;
    traefik_balanceador)
      docker rmi flotodor-traefik_balanceador-image:p5 -f
      docker build --no-cache -t flotodor-traefik_balanceador-image:p5 -f ./P5-flotodor-traefik/DockerfileTraefik_balanceador .
      ;;
    envoy_balanceador)
      docker rmi flotodor-envoy_balanceador-image:p5 -f
      docker build --no-cache -t flotodor-envoy_balanceador-image:p5 -f ./P5-flotodor-envoy/DockerfileEnvoy_balanceador .
      ;;
    all)
      build_image apache
      build_image nginx
      build_image haproxy_balanceador
      build_image nginx_balanceador
      build_image traefik_balanceador
      build_image envoy_balanceador
      ;;
    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx,nginx_balanceador, haproxy_balanceador, traefik_balanceador, envoy_balanceador o all${endColour}"
      ;;
  esac
}

# Función para crear redes si no existen, para evitar conflictos de IP
# Se crean dos redes: red_web y red_servicios
function ensure_networks() {
  declare -A redes=(
    ["red_web"]="192.168.10.0/24"
    ["red_servicios"]="192.168.20.0/24"
  )
  for red in "${!redes[@]}"; do
    if ! docker network ls --format '{{.Name}}' | grep -q "^${red}$"; then
      docker network create --driver bridge --subnet "${redes[$red]}" "$red" &>/dev/null
      echo -e "${greenColour}[✓] Red ${red} creada correctamente.${endColour}"
    else
      echo -e "${blueColour}[✓] Red ${red} ya existe.${endColour}"
    fi
  done
}

# Función para establecer la estrategia de balanceo de carga en HAProxy
# Se copia el archivo de configuración correspondiente a la estrategia seleccionada
# y se muestra un mensaje indicando la estrategia utilizada
# Se espera que el archivo de configuración esté en la ruta ./P5-flotodor-haproxy/config_balanceador/
#Las estrategias disponibles son: menor número de conexiones (lc) y round-robin (rb) y por defecto se usa round-robin
function set_haproxy_strategy() {
  local strategy=$1
  case "$strategy" in
    lc)
      cp ./P5-flotodor-haproxy/config_balanceador/haproxy_lc.cfg ./P5-flotodor-haproxy/config_balanceador/haproxy.cfg
      echo -e "${blueColour}[i] Estrategia de balanceo: menor número de conexiones${endColour}"
      ;;
    rb|"")
      cp ./P5-flotodor-haproxy/config_balanceador/haproxy_rb.cfg ./P5-flotodor-haproxy/config_balanceador/haproxy.cfg
      echo -e "${blueColour}[i] Estrategia de balanceo: round-robin (por defecto)${endColour}"
      ;;
    *)
      echo -e "${redColour}[!] Estrategia desconocida: $strategy. Usa 'lc' o 'rb'.${endColour}"
      return 1
      ;;
  esac
}

# Función para establecer la estrategia de balanceo de carga en Nginx
# Se copia el archivo de configuración correspondiente a la estrategia seleccionada
# y se muestra un mensaje indicando la estrategia utilizada
# Se espera que el archivo de configuración esté en la ruta ./P5-flotodor-nginx/config_balanceador/
#Las estrategias disponibles son: ponderación (pd) y round-robin (rb) y por defecto se usa round-robin
function set_nginx_strategy() {
  local strategy=$1
  case "$strategy" in
    pd)
      cp ./P5-flotodor-nginx/config_balanceador/nginx_pd.conf ./P5-flotodor-nginx/config_balanceador/nginx.conf
      echo -e "${blueColour}[i] Estrategia de balanceo: ponderación con pesos${endColour}"
      ;;
    rb|"")
      cp ./P5-flotodor-nginx/config_balanceador/nginx_rb.conf ./P5-flotodor-nginx/config_balanceador/nginx.conf
      echo -e "${blueColour}[i] Estrategia de balanceo: round-robin (por defecto)${endColour}"
      ;;
    *)
      echo -e "${redColour}[!] Estrategia desconocida: $strategy. Usa 'rb' o 'pd'.${endColour}"
      return 1
      ;;
  esac
}



# Función para comprobar la disponibilidad de los puertos 8080 a 8089
# Se utiliza lsof o ss para verificar si los puertos están en uso
function check_ports_availability() {
  echo -e "${yellowColour}[i] Comprobando puertos 8080 a 8089...${endColour}"
  local busy=false

  for port in {8080..8089}; do
    local pid=$(lsof -ti :$port 2>/dev/null || ss -ltnp 2>/dev/null | grep ":$port " | awk -F 'pid=' '{print $2}' | cut -d',' -f1)
    if [ ! -z "$pid" ]; then
      local pname=$(ps -p $pid -o comm= 2>/dev/null)
      echo -e "${redColour}[!] El puerto $port está en uso por el proceso $pname (PID $pid).${endColour}"
      busy=true
    fi
  done

  $busy && return 1 || return 0
}

# Función para detener balanceadores en conflicto
# Se verifica si hay un balanceador de tipo Nginx o HAProxy en ejecución y se detiene en el caso de que el usuario quiera cambiar de balanceador con este script
function stop_conflicting_balanceador() {
  local selected=$1
  local balanceadores=("nginx_balanceador" "haproxy_balanceador" "traefik_balanceador" "envoy_balanceador")

  for bal in "${balanceadores[@]}"; do
    # Extraemos el nombre base para comparar con el tipo seleccionado
    local tipo="${bal%%_balanceador}"
    
    if [ "$tipo" != "$selected" ] && docker ps --format '{{.Names}}' | grep -q "^${bal}$"; then
      echo -e "${yellowColour}[!] Se detectó ${bal} corriendo. Deteniéndolo...${endColour}"
      docker stop "$bal" &>/dev/null
      docker rm "$bal" &>/dev/null
      echo -e "${greenColour}[✓] ${bal} detenido.${endColour}"
    fi
  done
}


# Función para iniciar el balanceador de carga
# Se utiliza docker compose para levantar el balanceador de carga especificado, esto se utiliza para cuando el usuario quiere cambiar de tipo de balanceador en mitad de 
#la ejecución
function start_balanceador() {
  local type=$1
  case $type in
    nginx)
      docker compose -f docker-compose_nginx_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con Nginx.${endColour}"
      ;;
    haproxy)
      docker compose -f docker-compose_haproxy_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con HAProxy.${endColour}"
      ;;
    traefik)
      docker compose -f docker-compose_traefik_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con Traefik.${endColour}"
      ;;
    envoy)
      docker compose -f docker-compose_envoy_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con envoy.${endColour}"
      ;;
    escalado)
      docker compose -f docker-compose_escalado_automatico.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con monitorización y escalado automático.${endColour}"
      ;;
    *)
      echo -e "${redColour}[!] Especifica el tipo de balanceador: nginx, haproxy, traefik, envoy o escalado ${endColour}"
      return 1
      ;;
  esac
}

# Función para reiniciar el balanceador de carga Nginx si ya está en ejecución
# Se detiene y elimina el contenedor existente y se inicia uno nuevo con la nueva estrategia
# Se utiliza para cambiar de estrategia de balanceo, con balanceador nginx.
# Por ello primero tenemos que pararlo y eliminarlo, para luego volver a levantarlo, con la nueva estrategia
function force_restart_balanceador_si_nginx() {
  local type=$1
  local strategy=$2

  if [ "$strategy" == "" ]; then
    strategy="rb"
  fi 
  if [ "$type" == "nginx" ] && docker ps --format '{{.Names}}' | grep -q "^nginx_balanceador$"; then
    echo -e "${yellowColour}[!] nginx_balanceador ya está corriendo. Reiniciándolo para aplicar nueva estrategia...${endColour}"
    docker stop nginx_balanceador &>/dev/null
    docker rm nginx_balanceador &>/dev/null
    echo -e "${greenColour}[✓] nginx_balanceador reiniciado con la estrategia ${strategy}.${endColour}"
  fi
}

# Función para reiniciar el balanceador de carga HAProxy si ya está en ejecución
# Se detiene y elimina el contenedor existente y se inicia uno nuevo con la nueva estrategia
# Se utiliza para cambiar de estrategia de balanceo, con balanceador haproxy.
# Por ello primero tenemos que pararlo y eliminarlo, para luego volver a levantarlo, con la nueva estrategia
function force_restart_balanceador_si_haproxy() {
  local type=$1
  local strategy=$2

  if [ "$strategy" == "" ]; then
    strategy="rb"
  fi 
  if [ "$type" == "haproxy" ] && docker ps --format '{{.Names}}' | grep -q "^haproxy_balanceador$"; then
    echo -e "${yellowColour}[!] haproxy_balanceador ya está corriendo. Reiniciándolo para aplicar nueva estrategia...${endColour}"
    docker stop haproxy_balanceador &>/dev/null
    docker rm haproxy_balanceador &>/dev/null
    echo -e "${greenColour}[✓] haproxy_balanceador reiniciado con la estrategia ${strategy}.${endColour}"
  fi
}




#Función principal para ejecutar docker compose up
# Se asegura de que las redes necesarias estén creadas y disponibles
# Se comprueba la disponibilidad de los puertos y se detienen balanceadores en conflicto
# Se inicia el balanceador de carga especificado (nginx o haproxy)
# Se utiliza para levantar el balanceador de carga y los contenedores web
function compose_up() {
  local type=$1
  local strategy=$2

  ensure_networks

  if [ "$type" == "nginx" ]; then
    set_nginx_strategy "$strategy" || return
  fi

  if [[ "$type" == "haproxy" || "$type" == "escalado" ]]; then
  set_haproxy_strategy "$strategy" || return
fi


  # Primero detener balanceadores en conflicto
  stop_conflicting_balanceador "$type"
  force_restart_balanceador_si_nginx "$type" "$strategy"
  force_restart_balanceador_si_haproxy "$type" "$strategy"

  # Luego comprobar puertos
  check_ports_availability || {
    echo -e "${redColour}[X] Algunos puertos están ocupados. Aborta ejecución de docker compose up.${endColour}"
    return
  }

  start_balanceador "$type"
}


# Función para actualizar los contenedores web y balanceadores activos
function update_in_containers(){
  echo -e "${yellowColour}[i] Buscando contenedores web y balanceadores activos...${endColour}"
  updated=false
  for i in {1..9}; do
    if docker ps --format '{{.Names}}' | grep -q "^web$i$"; then
      docker exec web$i bash -c "apt-get update && apt-get upgrade -y" &>/dev/null
      echo -e "${greenColour}[✓] web$i actualizado correctamente.${endColour}"
      updated=true
    fi
  done
  for container in $(docker ps --format '{{.Names}}' | grep -i "balanceador"); do
    docker exec "$container" bash -c "apt-get update && apt-get upgrade -y" &>/dev/null
    echo -e "${greenColour}[✓] $container actualizado correctamente.${endColour}"
    updated=true
  done
  if [ "$updated" = false ]; then
    echo -e "${yellowColour}[!] No hay contenedores web ni balanceadores activos para actualizar.${endColour}"
  fi
}

# Función para limpiar los logs de los contenedores
# Se eliminan los archivos de logs en los directorios logs_apache y logs_nginx
function clear_logs(){
  for dir in logs_apache logs_nginx logs_envoy logs_haproxy logs_traefik logs_escalado; do
    if [ -d "$dir" ]; then
      if [ "$(ls -A $dir)" ]; then
        rm -f "$dir"/* 2>/dev/null
        echo -e "${greenColour}[✓] Archivos de logs en $dir eliminados.${endColour}"
      else
        echo -e "${redColour}[-] No hay archivos de logs en $dir para eliminar.${endColour}"
      fi
    else
      echo -e "${redColour}[!] Directorio $dir no encontrado.${endColour}"
    fi
  done
}


while getopts "s:b:u:pch" arg; do
  case $arg in
    c) clear_logs;;
    s) stop_and_remove $OPTARG;;
    b) build_image $OPTARG;;
    u)
      BAL_TYPE=$OPTARG
      STRATEGY=${!OPTIND} && shift
      compose_up "$BAL_TYPE" "$STRATEGY"

      if [ "$BAL_TYPE" == "escalado" ]; then
        rm -f stop_escalador.flag
        if command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "./escalador.sh; echo '[i] Escalador detenido. Cerrando terminal...'; sleep 1"
        echo -e "${greenColour}[✓] Escalador iniciado en nueva terminal (gnome-terminal)${endColour}"
        else
         bash escalador.sh &
         echo -e "${yellowColour}[!] No se encontró terminal gráfico. Ejecutando en segundo plano.${endColour}"
        fi
      fi
      ;;
    p) update_in_containers;;
    h) helpPanel;;
    *) helpPanel;;
  esac


done

if [ $# -eq 0 ]; then
  helpPanel
fi
