#!/usr/bin/env bash
# Runs every scenario in turn, checks what the server serves, and prints a summary.
set -uo pipefail
cd "$(dirname "$0")/.." || exit
PORT="${PORT:-8443}"
mkdir -p logs

[[ -f certs/fingerprints.txt ]] || scripts/gen-certs.sh || exit 1
# Always rebuild so the jar matches the Spring Boot version currently in pom.xml.
mvn -q -DskipTests package || exit 1

# Do not leave a server running if the script is interrupted (Ctrl-C).
pid=""
trap '[[ -n "$pid" ]] && kill "$pid" 2>/dev/null' EXIT

#  scenario expected
SCENARIOS=( "1-jks|JKS identity"
            "1b-jks-wrong-password|startup fails"
            "2-pem-over-jks|PEM identity"
            "2b-pem-over-jks-dummy-password|PEM identity"
            "3-pem-only|PEM identity" )

summary=()
for entry in "${SCENARIOS[@]}"; do
  scenario="${entry%%|*}"; expected="${entry##*|}"
  echo
  echo "=================== $scenario ==================="
  # Something else already listening would be mistaken for our server.
  if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
    echo "ERROR: port $PORT is already in use. Stop that process or set PORT=..." >&2
    exit 1
  fi
  SKIP_BUILD=1 PORT="$PORT" scripts/run.sh "$scenario" > "logs/$scenario.log" 2>&1 &
  pid=$!

  # Wait until the port answers or the process exits (max 60s).
  up=no
  for _ in $(seq 1 60); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then up=yes; break; fi
    sleep 1;
  done

  if [[ "$up" == yes ]]; then
    result=$(scripts/verify.sh "$PORT" | tee /dev/stderr | sed -n 's/^RESULT: serving the //p')
  else
    echo "Server did not start. Last error lines from logs/$scenario.log:"
    grep -iE "password was incorrect|tampered|Caused by" "logs/$scenario.log" | tail -3
    # Only a wrong keystore password counts; any other failure must not pass as expected.
    if grep -q "password was incorrect" "logs/$scenario.log"; then
      result="startup fails"
    else
      result="other failure"
    fi
  fi

  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  # Make sure the port is free before the next scenario starts.
  for _ in $(seq 1 60); do
    (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null || break
    sleep 1
  done

  [[ "$result" == "$expected" ]] && verdict="OK" || verdict="DIFFERENT"
  summary+=("$(printf '%-34s | %-14s | %-14s | %s' "$scenario" "$expected" "$result" "$verdict")")
done

echo
echo "=================== Summary ==================="
printf '%-34s | %-14s | %-14s | %s\n' "Scenario" "Expected" "Observed" "Match"
printf '%s\n' "${summary[@]}"
