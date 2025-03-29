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

function ctrl_c(){
  echo -e "\n ${redColour}[!] Saliendo....${endColour}"
}

function helpPanel(){
  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Uso:${endColour}\n"
  echo -e "\t${purpleColour}-c${endColour}${grayColour} Limpiar archivos dentro de logs_apache y logs_nginx${endColour}"
  echo -e "\t${purpleColour}-s${endColour}${grayColour} Detener y eliminar contenedores (apache/nginx/haproxy/all)${endColour}"
  echo -e "\t${purpleColour}-b${endColour}${grayColour} Crear imagen docker (apache/nginx/haproxy/all)${endColour}"
  echo -e "\t${purpleColour}-u${endColour}${grayColour} Ejecutar docker compose up (nginx/haproxy)${endColour}"
  echo -e "\t${purpleColour}-p${endColour}${grayColour} Actualizar paquetes dentro de los contenedores activos${endColour}"
  echo -e "\t${purpleColour}-h${endColour}${grayColour} Mostrar este panel de ayuda${endColour}\n"
}

function stop_and_remove() {
  local type=$1
  local containers=""

  case $type in
    apache)
      containers="web1 web3 web5 web7"
      ;;
    nginx)
      containers="web2 web4 web6 web8 nginx_balanceador"
      ;;
    haproxy)
      containers="haproxy_balanceador"
      ;;
    all)
      containers="web1 web2 web3 web4 web5 web6 web7 web8 nginx_balanceador haproxy_balanceador"
      ;;
    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx, haproxy o all${endColour}"
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
}

function build_image(){
  case $1 in
    apache)
      docker rmi flotodor-apache-image:p2 -f
      docker build -t flotodor-apache-image:p2 -f ./P2-flotodor-apache/DockerfileApache_florin .
      ;;
    nginx)
      docker rmi flotodor-nginx_web-image:p2 -f
      docker build -t flotodor-nginx_web-image:p2 -f ./P2-flotodor-nginx/DockerfileNginx_web .
      docker rmi flotodor-nginx_balanceador-image:p2 -f
      docker build -t flotodor-nginx_balanceador-image:p2 -f ./P2-flotodor-nginx/DockerfileNginx_balanceador .
      ;;
    haproxy)
      docker rmi flotodor-haproxy_balanceador-image:p2 -f
      docker build -t flotodor-haproxy_balanceador-image:p2 -f ./P2-flotodor-haproxy/DockerfileHAproxy_balanceador .
      ;;
    all)
      build_image apache
      build_image nginx
      build_image haproxy
      ;;
    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx, haproxy o all${endColour}"
      ;;
  esac
}

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


function compose_up(){
  local type=$1
  ensure_networks

  echo -e "${yellowColour}[i] Comprobando puertos 8080 a 8089...${endColour}"
  busy=false
  for port in {8080..8089}; do
    pid=$(lsof -ti :$port 2>/dev/null)
    if [ -z "$pid" ]; then
      pid=$(ss -ltnp 2>/dev/null | grep ":$port " | awk -F 'pid=' '{print $2}' | cut -d',' -f1)
    fi
    if [ ! -z "$pid" ]; then
      pname=$(ps -p $pid -o comm= 2>/dev/null)
      echo -e "${redColour}[!] El puerto $port está en uso por el proceso $pname (PID $pid).${endColour}"
      busy=true
    fi
  done

  if [ "$busy" = true ]; then
    echo -e "${redColour}[X] Algunos puertos están ocupados. Aborta ejecución de docker compose up.${endColour}"
    return
  fi

  # Autodetener balanceador en conflicto
  if [ "$type" == "nginx" ] && docker ps --format '{{.Names}}' | grep -q "^haproxy_balanceador$"; then
    echo -e "${yellowColour}[!] Se detectó haproxy_balanceador corriendo. Deteniéndolo...${endColour}"
    docker stop haproxy_balanceador &>/dev/null
    docker rm haproxy_balanceador &>/dev/null
    echo -e "${greenColour}[✓] haproxy_balanceador detenido.${endColour}"
  elif [ "$type" == "haproxy" ] && docker ps --format '{{.Names}}' | grep -q "^nginx_balanceador$"; then
    echo -e "${yellowColour}[!] Se detectó nginx_balanceador corriendo. Deteniéndolo...${endColour}"
    docker stop nginx_balanceador &>/dev/null
    docker rm nginx_balanceador &>/dev/null
    echo -e "${greenColour}[✓] nginx_balanceador detenido.${endColour}"
  fi

  # Ejecutar docker compose up del balanceador seleccionado
  case $type in
    nginx)
      docker compose -f docker-compose_nginx_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con Nginx.${endColour}"
      ;;
    haproxy)
      docker compose -f docker-compose_haproxy_balanceador.yaml up -d --remove-orphans
      echo -e "${greenColour}[+] Servicios iniciados con HAProxy.${endColour}"
      ;;
    *)
      echo -e "${redColour}[!] Especifica el tipo de balanceador: nginx o haproxy${endColour}"
      ;;
  esac
}

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

function clear_logs(){
  for dir in logs_apache logs_nginx; do
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
    u) compose_up $OPTARG;;
    p) update_in_containers;;
    h) helpPanel;;
    *) helpPanel;;
  esac

done

if [ $# -eq 0 ]; then
  helpPanel
fi
