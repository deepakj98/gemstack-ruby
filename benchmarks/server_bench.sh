#!/usr/bin/env bash
# End-to-end throughput through Puma (5 threads, 1 process) with ApacheBench.
# Usage: benchmarks/server_bench.sh [requests] [concurrency]
set -euo pipefail
cd "$(dirname "$0")/.."
N=${1:-20000}; C=${2:-10}; PORT=${PORT:-58080}
for jit in off yjit zjit; do
  GEMSTACK_JIT=$jit bundle exec puma -q -t 5:5 -b "tcp://127.0.0.1:$PORT" benchmarks/server/config.ru > /dev/null 2>&1 &
  pid=$!
  until curl -sf "http://127.0.0.1:$PORT/api/health" > /dev/null; do sleep 0.2; done
  ab -q -k -n 2000 -c "$C" "http://127.0.0.1:$PORT/api/products" > /dev/null # warm up (JIT compilation)
  for enc in identity br; do
    runs=()
    for _ in 1 2 3 4 5; do
      runs+=("$(ab -q -k -n "$N" -c "$C" -H "Accept-Encoding: $enc" "http://127.0.0.1:$PORT/api/products" |
                awk '/Requests per second/ {print $4}')")
    done
    median=$(printf "%s\n" "${runs[@]}" | sort -n | sed -n 3p)
    printf "%-5s %-9s median %8s req/s   (runs: %s)\n" "$jit" "$enc" "$median" "${runs[*]}"
  done
  kill "$pid"; wait "$pid" 2> /dev/null || true
done
