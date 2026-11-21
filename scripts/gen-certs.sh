#!/usr/bin/env bash
# Generates throwaway test material under ./certs:
#   - a demo CA
#   - identity A, packaged as a JKS (key + leaf + CA chain, plus the CA as a trusted entry)
#   - identity B, packaged as ONE combined PEM file (leaf certificate + private key, no chain)
# The two identities have different keys and certificates on purpose, so the
# served fingerprint shows unambiguously which one the server is using.
set -euo pipefail

# Run a command without its normal noise; if it fails, show what it printed.
quiet() {
  local out
  if ! out=$("$@" 2>&1); then
    echo "ERROR: command failed: $*" >&2
    echo "$out" >&2
    return 1
  fi
}

cd "$(dirname "$0")/.."

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
quiet openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout certs/ca/ca.key -out certs/ca/ca.crt \
  -subj "/O=TLS Demo/CN=Demo Server CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

issue() {
  # issue <dir> <name> <OU> <days>
  quiet openssl req -newkey rsa:2048 -nodes \
    -keyout "$1/$2.key" -out "$1/$2.csr" \
    -subj "/O=TLS Demo/OU=$3/CN=localhost"
  quiet openssl x509 -req -in "$1/$2.csr" -CA certs/ca/ca.crt -CAkey certs/ca/ca.key \
    -CAcreateserial -days "$4" -extfile certs/leaf-ext.cnf -out "$1/$2.crt"
  rm -f "$1/$2.csr"
}

echo "== Identity A (JKS)"
issue certs/jks jks-identity "JKS identity" 365
quiet openssl pkcs12 -export -name demo \
  -inkey certs/jks/jks-identity.key -in certs/jks/jks-identity.crt -certfile certs/ca/ca.crt \
  -out certs/jks/tmp.p12 -passout "pass:$PASS"
quiet keytool -importkeystore -noprompt \
  -srckeystore certs/jks/tmp.p12 -srcstoretype PKCS12 -srcstorepass "$PASS" \
  -destkeystore certs/jks/demo.jks -deststoretype JKS -deststorepass "$PASS"
quiet keytool -importcert -noprompt -alias demo-ca -file certs/ca/ca.crt \
  -keystore certs/jks/demo.jks -storepass "$PASS"
rm -f certs/jks/tmp.p12 certs/jks/jks-identity.key

echo "== Identity B (combined PEM: certificate + private key, leaf only)"
issue certs/pem pem-identity "PEM identity" 358
cat certs/pem/pem-identity.crt certs/pem/pem-identity.key > certs/pem/demo-host.pem
chmod 400 certs/pem/demo-host.pem
rm -f certs/pem/pem-identity.key

fp() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 | cut -d= -f2
}

{
  echo "JKS $(fp certs/jks/jks-identity.crt)"
  echo "PEM $(fp certs/pem/pem-identity.crt)"
} > certs/fingerprints.txt

echo
echo "Done. Fingerprint (SHA-256):"
cat certs/fingerprints.txt
