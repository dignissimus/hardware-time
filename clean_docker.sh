#!/bin/bash

# Script to clean all Docker resources

echo "Stopping all running containers..."
docker stop $(docker ps -aq) 2>/dev/null || echo "No running containers found."

echo "Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || echo "No containers to remove."

echo "Removing all images..."
docker rmi $(docker images -q) --force 2>/dev/null || echo "No images to remove."

echo "Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || echo "No volumes to remove."

echo "Removing all networks..."
docker network rm $(docker network ls -q) 2>/dev/null || echo "No networks to remove."

echo "Pruning system..."
docker system prune -af --volumes

echo "Docker cleanup complete!"
