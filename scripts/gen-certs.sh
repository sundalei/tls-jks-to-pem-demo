#!/usr/bin/env bash
# Generates throwaway test material under ./certs:
#   - a demo CA
#   - identity A, packaged as a JKS (key + leaf + CA chain, plus the CA as a trusted entry)
#   - identity B, packaged as ONE combined PEM file (leaf certificate + private key, no chain)
# The two identities have different keys and certificates on purpose, so the
# served fingerprint shows unambiguously which one the server is using.
set -euo pipefail
echo "$(dirname "$0")/.."

PASS=changeit
rm -rf certs
mkdir -p certs/ca certs/jks certs/pem

cat > certs/leaf-ext.cnf <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF

echo "== Demo CA"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout certs/ca/ca.key -out certs/ca/ca.crt \
  -subj "/O=TLS Demo/CN=Demo Server CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

issue() {
  # issue <dir> <name> <OU> <days>
  openssl req -newkey rsa:2048 -nodes \
    -keyout "$1/$2.key" -out "$1/$2.csr" \
    -subj "/O=TLS Demo/OU=$3/CN=localhost" 2>/dev/null
  openssl x509 -req -in "$1/$2.csr" -CA certs/ca/ca.crt -CAkey certs/ca/ca.key \
    -CAcreateserial -days "$4" -extfile certs/leaf-ext.cnf -out "$1/$2.crt" 2>/dev/null
  rm -f "$1/$2.csr"
}

echo "== Identity A (JKS)"
issue certs/jks jks-identity "JKS identity" 365

echo "Generating certificates done"
