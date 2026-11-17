#!/usr/bin/env bash
# Starts the app for one scenario in the foreground.
# Usage: scripts/run.sh <scenario>  e.g. scripts/run.sh 2-pem-over-jks
# Then, in another terminal: scripts/verify.sh
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" || ! -d "config/$SCENARIO" ]]; then
  echo "Usage: scripts/run.sh <scenario>"
  echo "Scenarios:"; ls config | sed 's/^/  /'
  exit 1
fi

[[ -f certs/fingerprints.txt ]] || scripts/gen-certs.sh
[[ -f target/tls-demo.jar ]] || mvn -DskipTests package

ARGS=("--spring.config.additional-location=file:./config/$SCENARIO/" "--server.port=${PORT:-8443}")
# Scenarios 1x and 2x run against "today's jar", which has the keystore lines baked in.
case "$SCENARIO" in
  1*|2*) ARGS+=("--spring.profiles.active=legacy") ;;
esac

echo "Starting scenario $SCENARIO: java -jar target/tls-demo.jar ${ARGS[*]}"
exec java -jar target/tls-demo.jar "${ARGS[@]}"
