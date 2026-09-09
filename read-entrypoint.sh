#!/bin/sh
# Read the middle of the entrypoint script
docker exec openbao sh -c "sed -n '40,100p' /usr/local/bin/docker-entrypoint.sh"
