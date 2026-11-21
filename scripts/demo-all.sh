#!/usr/bin/env bash
# Runs every scenario in turn, checks what the server serves, and prints a summary.
set -uo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-8443}"
mkdir -p logs

[[ -f certs/fingerprints.txt ]] || scripts/gen-certs.sh || exit 1
[[ -f target/tls-demo.jar ]] || mvn -DskipTests package || exit 1

#  scenario expected
SCENARIOS=( "1-jks|JKS identity"
            "1b-jks-wrong-password|startup fails"
            "2-pem-over-jks|PEM identity"
            "2b-pem-over-jks-dummy-password|PEM identity"
            "3-pem-only|PEM identity" )

summary=()
for entry in "${SCENARIOS[@]}"; do
  echo $entry
done
