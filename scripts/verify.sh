#!/usr/bin/env bash
# Asks the running server which certificate it serves and says whether that is
# the JKS identity or the PEM identity. Usage: scripts/verify.sh [port]
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${1:-8443}"

out=$(echo | openssl s_client -connect "localhost:$PORT" -servername localhost -showcerts 2>/dev/null)
if ! grep -q "BEGIN CERTIFICATE" <<<"$out"; then
  echo "RESULT: no TLS server answered on port $PORT"
  exit 2
fi

count=$(grep -c "BEGIN CERTIFICATE" <<<"$out")
echo $count
