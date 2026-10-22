#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PROJECT_DIR"

SERVICES=(db redis app nginx)
STATUS_OUTPUT="$(docker compose ps --all --format '{{.Service}}|{{.State}}|{{.Health}}')"
ALL_HEALTHY=true

for SERVICE in "${SERVICES[@]}"; do
  LINE="$(printf '%s\n' "$STATUS_OUTPUT" | awk -F'|' -v service="$SERVICE" '$1 == service { print; exit }')"
  if [[ -z "$LINE" ]]; then
    echo "$SERVICE: stopped or not created"
    ALL_HEALTHY=false
    continue
  fi

  IFS='|' read -r _ STATE HEALTH <<< "$LINE"
  if [[ "$STATE" != "running" ]]; then
    echo "$SERVICE: $STATE"
    ALL_HEALTHY=false
  elif [[ -n "$HEALTH" && "$HEALTH" != "healthy" ]]; then
    echo "$SERVICE: $HEALTH"
    ALL_HEALTHY=false
  elif [[ -n "$HEALTH" ]]; then
    echo "$SERVICE: healthy"
  else
    echo "$SERVICE: running (no health check defined)"
  fi
done

if [[ "$ALL_HEALTHY" == true ]]; then
  echo "All services are running and healthy where a health check is defined."
else
  echo "One or more services are stopped or unhealthy." >&2
  exit 1
fi
