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

# Salir del programa con Ctrl+C y recuperar el cursor
function ctrl_c(){
  echo -e "\n ${redColour}[!] Saliendo....${endColour}"
}

trap ctrl_c INT

function helpPanel(){
  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Uso:${endColour}\n"
  echo -e "\t${purpleColour}-c${endColour}${grayColour} Limpiar archivos dentro de logs_apache y logs_nginx${endColour}"
  echo -e "\t${purpleColour}-s${endColour}${grayColour} Detener y eliminar contenedores (apache/nginx/all)${endColour}"
  echo -e "\t${purpleColour}-b${endColour}${grayColour} Crear imagen docker (apache/nginx/all)${endColour}"
  echo -e "\t${purpleColour}-u${endColour}${grayColour} Ejecutar docker compose up${endColour}"
  echo -e "\t${purpleColour}-p${endColour}${grayColour} Actualizar paquetes dentro de los contenedores activos${endColour}"
  echo -e "\t${purpleColour}-h${endColour}${grayColour} Mostrar este panel de ayuda${endColour}\n"
}

# Función para detener y eliminar contenedores
function stop_and_remove() {
  local type=$1
  local containers=""

    # Elegir contenedores apache, nginx o ambos
  case $type in
    apache)
      containers="web1 web3 web5 web7 web9"
      ;;
    nginx)
      containers="web2 web4 web6 web8"
      ;;
    all)
      containers="web1 web2 web3 web4 web5 web6 web7 web8 web9"
      ;;
    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx o all${endColour}"
      return
      ;;
  esac

  # Filtrar los contenedores que realmente existen
  local existing=()
  for name in $containers; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
      existing+=("$name")
    fi
  done

  if [ ${#existing[@]} -eq 0 ]; then
    case $type in
      apache) echo -e "${yellowColour}[!] No se encontraron contenedores Apache (web impar)${endColour}" ;;
      nginx)  echo -e "${yellowColour}[!] No se encontraron contenedores Nginx (web par)${endColour}" ;;
      all)    echo -e "${yellowColour}[!] No se encontraron contenedores para eliminar (web1 a web9)${endColour}" ;;
    esac
  else
    # Si existen contenedores, detener y eliminar
    docker stop "${existing[@]}" &>/dev/null 
    docker rm -f "${existing[@]}" &>/dev/null
    for name in "${existing[@]}"; do
      echo -e "${greenColour}[+] Contenedor ${name} detenido y eliminado${endColour}"
    done

    remove_networks # Eliminar redes
  fi
}

# Función para construir imágenes según los dockerfiles
function build_image(){
  case $1 in
    apache)
      docker rmi flotodor-apache-image:p1 -f
      docker build -t flotodor-apache-image:p1 -f DockerfileApache_florin .
      echo -e "${greenColour}[+] Imagen de Apache construida como flotodor-apache-image:p1${endColour}"
    ;;

    nginx)
      docker rmi flotodor-nginx-image:p1 -f
      docker build -t flotodor-nginx-image:p1 -f DockerfileNginx_florin .
      echo -e "${greenColour}[+] Imagen de Nginx construida como flotodor-nginx-image:p1${endColour}"
    ;;

    all)
      docker rmi flotodor-apache-image:p1 flotodor-nginx-image:p1 -f
      docker build -t flotodor-apache-image:p1 -f DockerfileApache_florin .
      docker build -t flotodor-nginx-image:p1 -f DockerfileNginx_florin .
      echo -e "${greenColour}[+] Imágenes de Apache y Nginx construidas correctamente${endColour}"
    ;;

    *)
      echo -e "${redColour}[!] Selecciona: apache, nginx o all${endColour}"
    ;;
  esac
}

# Función para eliminar redes
function remove_networks(){
  docker network rm p1_red_web p1_red_servicios 2>/dev/null
  echo -e "${greenColour}[+] Redes Docker eliminadas.${endColour}"
}

# Función para comprobar puertos y ejecutar docker compose up
function compose_up(){
  echo -e "${yellowColour}[i] Comprobando puertos 8081 a 8089...${endColour}"
  busy=false
  # Comprobar si los puertos 8081 a 8089 están ocupados
  for port in {8081..8089}; do
    pid=$(lsof -ti :$port 2>/dev/null)
    
    if [ -z "$pid" ]; then
      # Si lsof no devuelve nada, intentar con ss
      pid=$(ss -ltnp 2>/dev/null | grep ":$port " | awk -F 'pid=' '{print $2}' | cut -d',' -f1)
    fi
    # Si el puerto está ocupado, mostrar el proceso que lo está usando

    if [ ! -z "$pid" ]; then
      pname=$(ps -p $pid -o comm= 2>/dev/null)
      echo -e "${redColour}[!] El puerto $port está en uso por el proceso $pname (PID $pid).${endColour}"
      busy=true
    fi
  done

# Si algún puerto está ocupado, abortar la ejecución de docker compose up
  if [ "$busy" = true ]; then
    echo -e "${redColour}[X] Algunos puertos están ocupados. Aborta ejecución de docker compose up.${endColour}"
  else
    # Si todos los puertos están libres, ejecutar docker compose up
    docker compose up -d
    echo -e "${greenColour}[+] Servicios iniciados con docker compose.${endColour}"
  fi
}

function update_in_containers(){
  echo -e "${yellowColour}[i] Buscando contenedores web activos...${endColour}"
  
  updated=false

# Actualizar paquetes en los contenedores web1 a web9
  for i in {1..9}; do
    if docker ps --format '{{.Names}}' | grep -q "^web$i$"; then
      echo -e "${blueColour}[+] Actualizando paquetes en web$i...${endColour}"
      docker exec web$i bash -c "apt-get update && apt-get upgrade -y" &>/dev/null

      if [ $? -eq 0 ]; then
        echo -e "${greenColour}[✓] web$i actualizado correctamente.${endColour}"
      else
        echo -e "${redColour}[✗] Error actualizando web$i.${endColour}"
      fi

      updated=true
    fi
  done

  if [ "$updated" = false ]; then
    echo -e "${yellowColour}[!] No hay contenedores web activos para actualizar.${endColour}"
  fi
}

function clear_logs(){
  echo -e "${yellowColour}[i] Limpiando archivos de logs...${endColour}"
  
  # Asegurar que existen los directorios antes de intentar limpiarlos
  for dir in logs_apache logs_nginx; do
    if [ -d "$dir" ]; then
      rm -f $dir/* 2>/dev/null
      echo -e "${greenColour}[✓] Archivos de logs en $dir eliminados.${endColour}"
    else
      echo -e "${redColour}[!] Directorio $dir no encontrado.${endColour}"
    fi
  done
}


# Opciones
while getopts "s:b:upch" arg; do
  case $arg in  
    c) clear_logs;;
    s) stop_and_remove $OPTARG;;
    b) build_image $OPTARG;;
    u) compose_up;;
    p) update_in_containers;;
    h) helpPanel;;
    *) helpPanel;;
  esac
done

# Si no se pasa ningún parámetro, mostrar helpPanel
if [ $# -eq 0 ]; then
  helpPanel
fi