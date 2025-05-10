#!/usr/bin/env bash
#
# test_freq.sh  <URL>  [MODE]
# MODE:
#    ab      – 1000 peticiones, 100 concurrencias
#    curl    – 300 ráfagas rápidas con keep‑alive
#    slow    – Slowloris 200 sockets abiertos 180 s
#
URL=${1:-http://localhost}
[[ "$URL" =~ ^http ]] || URL="http://$URL"

set -e
echo "▶ URL: $URL   MODE: $MODE"

ts() { date +%s%3N; }

case "$MODE" in
  ab)
    echo "👉 ApacheBench 1000 × 100"
    ab -n 1000 -c 100 -k "$URL/" | tee ab.out
    ;;
  curl)
    echo "👉 300 peticiones con curl (10 hilos)"
    start=$(ts)
    for n in {1..10}; do
      (
        for i in {1..30}; do
          curl -s "$URL" -o /dev/null
        done
      ) &
    done
    wait
    end=$(ts); echo "⏱  $((${end}-${start})) ms"
    ;;
  slow)
    echo "👉 Lanzando Slowloris… (necesita slowhttptest)"
    slowhttptest -c 200 -H -i 10 -r 200 -t GET -u "$URL/" -x 24 -p 3 -l 180
    ;;
  *)
    echo "Uso: $0 <url> [ab|curl|slow]"; exit 1 ;;
esac
