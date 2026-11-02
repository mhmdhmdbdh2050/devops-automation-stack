#!/usr/bin/env bash
set -Eeuo pipefail

services=(db redis app nginx)
all_healthy=true

printf 'Checking Docker Compose service health...\n'
for service in "${services[@]}"; do
  state=$(docker compose ps --all --format '{{.State}}' "$service" 2>/dev/null || true)
  health=$(docker compose ps --all --format '{{.Health}}' "$service" 2>/dev/null || true)

  if [[ "$state" != running ]]; then
    printf '%s: %s\n' "$service" "${state:-not found}"
    all_healthy=false
  elif [[ "$health" == healthy ]]; then
    printf '%s: healthy\n' "$service"
  else
    printf '%s: running, health=%s\n' "$service" "${health:-not reported}"
    all_healthy=false
  fi
done

if [[ "$all_healthy" == true ]]; then
  exit 0
fi
exit 1
