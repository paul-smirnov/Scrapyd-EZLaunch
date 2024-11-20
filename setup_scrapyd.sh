#!/bin/bash

# Set username and generate random password if not provided
: ${SCRAPYD_USERNAME:=admin}
: ${SCRAPYD_PASSWORD:=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)}

# Fetch the public IP address (ensure curl is installed)
if command -v curl >/dev/null 2>&1; then
  PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
else
  PUBLIC_IP="localhost"
fi

# Pull the Scrapyd Docker image
echo "Pulling Docker image geeeq2/scrapyd-env..."
docker pull geeeq2/scrapyd-env

# Stop and remove any existing container with the same name
docker stop scrapyd 2>/dev/null || true
docker rm scrapyd 2>/dev/null || true

# Run the Scrapyd container
echo "Starting Scrapyd container..."
docker run -d --name scrapyd -p 6800:6800 \
  -e SCRAPYD_USERNAME=$SCRAPYD_USERNAME \
  -e SCRAPYD_PASSWORD=$SCRAPYD_PASSWORD \
  geeeq2/scrapyd-env

# Check if the container started successfully
if [ $? -ne 0 ]; then
  echo "Failed to start Scrapyd container. Please check the logs for details."
  exit 1
fi

# Save the credentials to a file
CREDENTIALS_FILE="scrapyd_credentials.txt"
echo "URL: http://${PUBLIC_IP}:6800" > $CREDENTIALS_FILE
echo "Username: $SCRAPYD_USERNAME" >> $CREDENTIALS_FILE
echo "Password: $SCRAPYD_PASSWORD" >> $CREDENTIALS_FILE

# Define color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Display container information with colors
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${CYAN} Scrapyd is now running in this container ${NC}"
echo -e "${GREEN}------------------------------------------${NC}"
echo -e "${YELLOW} URL      : http://${PUBLIC_IP}:6800 ${NC}"
echo -e "${YELLOW} Username : $SCRAPYD_USERNAME ${NC}"
echo -e "${YELLOW} Password : $SCRAPYD_PASSWORD ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${YELLOW} Credentials saved in file: $CREDENTIALS_FILE ${NC}"
echo ""

# Output the logs for the running container
echo "Container logs:"
docker logs scrapyd
