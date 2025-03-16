#!/bin/bash

sudo docker compose down
while true; do
    # Check if the container "docker-ap" is listed as healthy
    if docker ps | grep docker-ap | grep -q "(healthy)"; then
        echo "Container docker-ap is running and healthy."
        break
    else
        echo "Container docker-ap is not healthy. Restarting containers..."
        sudo docker compose down
        sudo docker compose up -d
        # Wait a few seconds before checking again
        sleep 10
    fi
done