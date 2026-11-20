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
served=$(openssl x509 -noout -fingerprint -sha256 <<<"$out" | cut -d= -f2)
subject=$(openssl x509 -noout -subject <<<"$out" | sed 's/^subject=//')
enddate=$(openssl x509 -noout -enddate <<<"$out" | sed 's/^notAfter=//')

jks=$(awk '$1=="JKS"{print $2}' certs/fingerprint.txt)
pem=$(awk '$1=="PEM"{print $2}' certs/fingerprint.txt)

case "$served" in
  "$jks") identity="JKS identity" ;;
  "$pem") identity="PEM identity" ;;
  *)      identity="UNKNOWN certificate" ;;
esac

# Trust check with a client that only knows the demo CA (leaf-only chains must still verify)
# This means the client has no access to additional certificates and must trust the server
# certificate using the demo CA alone, even when the server sends only its leaf certificate.
