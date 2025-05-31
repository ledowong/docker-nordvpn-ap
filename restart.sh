#!/bin/bash

sudo docker compose down
while true; do
    # Check if the container "docker-ap" is listed as healthy
    if docker ps | grep docker-ap | grep -q "(healthy)"; then
        echo "Container docker-ap is running and healthy."
        break
    else
        echo "Container docker-ap is not healthy. Restarting containers..."
        # Try docker compose down once.
        # Capture both stdout and stderr into a variable so we can inspect any “operation not permitted” error.
        if ! OUTPUT="$(sudo docker compose down 2>&1)"; then
        # Check if the failure was due to an immutable resolv.conf inside /var/lib/docker/containers
            if echo "$OUTPUT" | grep -q "operation not permitted" && echo "$OUTPUT" | grep -q "resolv\.conf"; then
                echo "Detected immutable resolv.conf error. Attempting to remove immutable flag and retry…"
                # Extract the exact /var/lib/docker/containers/<ID>/resolv.conf path from Docker’s error message.
                # We assume container IDs are 64 hex chars, so we grep for that full-path.
                FILE_PATH="$(echo "$OUTPUT" \
                | grep -oE "/var/lib/docker/containers/[0-9a-f]{64}/resolv\.conf" \
                | head -n1)"

                if [[ -n "$FILE_PATH" ]]; then
                echo "Running: sudo chattr -i $FILE_PATH"
                sudo chattr -i "$FILE_PATH" \
                    && echo "Immutable bit removed from $FILE_PATH" \
                    || { echo "Failed to remove immutable bit from $FILE_PATH"; exit 1; }

                # Now that the immutable bit is gone, retry docker compose down one more time.
                echo "Retrying docker compose down…"
                sudo docker compose down || {
                    echo "Second attempt to run 'docker compose down' still failed. Here was the output:"
                    exit 1
                }
                else
                echo "Could not parse the resolv.conf path from Docker’s error. Original output:"
                echo "$OUTPUT"
                exit 1
                fi
            else
                # Some other error (not “resolv.conf: operation not permitted”).
                echo "docker compose down failed for a different reason:"
                echo "$OUTPUT"
                exit 1
            fi
        else
            # First attempt succeeded—nothing more to do.
            echo "docker compose down completed successfully on the first try."
        fi
        sudo docker compose up -d
        # Wait a few seconds before checking again
        sleep 10
    fi
done