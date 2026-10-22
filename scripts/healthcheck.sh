#!/bin/bash

SERVICES=("tasks_db" "tasks_redis" "tasks_app" "tasks_nginx")
ALL_HEALTHY=true

echo "Checking service health..."
echo "-----------------------------"

for SERVICE in "${SERVICES[@]}"; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$SERVICE" 2>/dev/null)

    if [ -z "$STATUS" ]; then
        RUNNING=$(docker inspect --format='{{.State.Running}}' "$SERVICE" 2>/dev/null)
        if [ "$RUNNING" == "true" ]; then
            echo "$SERVICE: running (no healthcheck defined)"
        else
            echo "$SERVICE: stopped!"
            ALL_HEALTHY=false
        fi
    elif [ "$STATUS" == "healthy" ]; then
        echo "$SERVICE: healthy"
    else
        echo "$SERVICE: $STATUS"
        ALL_HEALTHY=false
    fi
done

echo "-----------------------------"

if [ "$ALL_HEALTHY" = true ]; then
    echo "All services are running properly"
    exit 0
else
    echo "One or more services have an issue!"
    exit 1
fi
