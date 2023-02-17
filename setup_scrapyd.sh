#!/bin/bash
set -euo pipefail

# Ensure the script is being run as root
ID=$(id -u)
if [ "0$ID" -ne 0 ]
  then echo "Please run this script as root"
  exit
fi
# -----------------------------------------------------------------------------
# 1. Insert the Docker check/install logic here
# -----------------------------------------------------------------------------

SKIP_DOCKER_INSTALL=no
if [ -x "$(command -v docker)" ]; then
  # The first condition is 'docker-compose (v1)' and the second is 'docker compose (v2)'.
  if [ -x "$(command -v docker-compose)" ] || (docker compose 1> /dev/null 2>& 1 && [ $? -eq 0 ]); then
    SKIP_DOCKER_INSTALL=yes
  fi
elif [ ! -f /etc/os-release ]; then
  echo "Unknown Linux distribution.  This script presently works only on Debian, Fedora, Ubuntu, and RHEL (and compatible)"
  exit
fi


# If Docker is not installed, run the distro-detection and installation logic:
if [ "$SKIP_DOCKER_INSTALL" = "no" ]; then

  # Distros recognized by the second script
  DISTRO=$(. /etc/os-release && echo "$ID")

  install_docker_debian() {
  echo "** Installing Docker (Debian) **"

  export DEBIAN_FRONTEND=noninteractive
  apt-get -qqy update
  DEBIAN_FRONTEND=noninteractive apt-get -qqy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
  apt-get -yy install apt-transport-https ca-certificates curl software-properties-common pwgen gnupg

  # Add Docker GPG signing key
  if [ ! -f "/etc/apt/keyrings/docker.gpg" ]; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Add Docker download repository to apt
  cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
  apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

  install_docker_fedora() {
  echo "** Installing Docker (Fedora) **"

  # Add Docker package repository
  dnf -qy install dnf-plugins-core
  dnf config-manager --quiet --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

  # Install Docker
  dnf install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin pwgen

  # Start Docker and enable it for automatic start at boot
  systemctl start docker && systemctl enable docker
}

  install_docker_rhel() {
  echo "** Installing Docker (RHEL and compatible) **"

  # Add EPEL package repository
  if [ "x$DISTRO" = "xrhel" ]; then
    # Genuine RHEL doesn't have the epel-release package in its repos
    RHEL_VER=$(. /etc/os-release && echo "$VERSION_ID" | cut -d "." -f1)
    if [ "0$RHEL_VER" -eq "9" ]; then
      yum install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    else
      yum install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    fi
    yum install -qy yum-utils
  else
    # RHEL compatible distros do have epel-release available
    yum install -qy epel-release yum-utils
  fi
  yum update -qy

  # Add Docker package repository
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum update -qy

  # Install Docker
  yum install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin pwgen

  # Start Docker and enable it for automatic start at boot
  systemctl start docker && systemctl enable docker
}

  install_docker_ubuntu() {
  echo "** Installing Docker (Ubuntu) **"

  export DEBIAN_FRONTEND=noninteractive
  apt-get -qqy update
  DEBIAN_FRONTEND=noninteractive sudo -E apt-get -qqy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
  apt-get -yy install apt-transport-https ca-certificates curl software-properties-common pwgen gnupg

  # Add Docker GPG signing key
  if [ ! -f "/etc/apt/keyrings/docker.gpg" ]; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Add Docker download repository to apt
  cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=""$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
  apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

  # Now do the actual check and invoke the relevant install function:
  case "$DISTRO" in
    debian)
      install_docker_debian
      ;;
    fedora)
      install_docker_fedora
      ;;
    ubuntu)
      install_docker_ubuntu
      ;;
    almalinux|centos|ol|rhel|rocky)
      install_docker_rhel
      ;;
    *)
      echo "This distro ($DISTRO) isn't recognized by our Docker installer logic."
      echo "Please install Docker manually and re-run."
      exit 1
      ;;
  esac
fi

# -----------------------------------------------------------------------------
# END Docker check/install logic
# -----------------------------------------------------------------------------

CREDENTIALS_FILE="scrapyd_credentials.txt"

##############################################################################
# 1) Build a Docker arguments array
##############################################################################
DOCKER_ARGS=( -d --name scrapyd -p 6800:6800 )

# Initialize these in case they get set by -e later
SCRAPYD_USERNAME="${SCRAPYD_USERNAME:-}"
SCRAPYD_PASSWORD="${SCRAPYD_PASSWORD:-}"

##############################################################################
# 2) Parse -e KEY=VAL arguments into DOCKER_ARGS
##############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      shift
      if [[ -n "${1:-}" && "$1" == *"="* ]]; then
        kv="$1"
        key="${kv%%=*}"     # everything before first "="
        val="${kv#*=}"      # everything after first "="
        # 1. Append to the DOCKER_ARGS array for Docker
        DOCKER_ARGS+=( -e "$key=$val" )

        # 2. Also set local script variables if they match
        if [[ "$key" == "SCRAPYD_USERNAME" ]]; then
          SCRAPYD_USERNAME="$val"
        elif [[ "$key" == "SCRAPYD_PASSWORD" ]]; then
          SCRAPYD_PASSWORD="$val"
        fi
      fi
      ;;
    *)
      # Ignore or handle other flags if needed
      ;;
  esac
  shift || true
done

##############################################################################
# 3) Credentials handling (scrapyd_username & scrapyd_password)
##############################################################################
if [ -f "$CREDENTIALS_FILE" ]; then
  echo "Credentials file found. Using saved credentials."
  SCRAPYD_USERNAME=$(grep "Username:" "$CREDENTIALS_FILE" | cut -d ' ' -f 2)
  SCRAPYD_PASSWORD=$(grep "Password:" "$CREDENTIALS_FILE" | cut -d ' ' -f 2)
else
  # If user didn't pass -e SCRAPYD_USERNAME=..., fallback to a default
  : "${SCRAPYD_USERNAME:=admin}"
  # If user didn't pass -e SCRAPYD_PASSWORD=..., generate a random one
  : "${SCRAPYD_PASSWORD:=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
fi

# Make sure these 2 environment variables are added to the container
DOCKER_ARGS+=( -e "SCRAPYD_USERNAME=$SCRAPYD_USERNAME" )
DOCKER_ARGS+=( -e "SCRAPYD_PASSWORD=$SCRAPYD_PASSWORD" )

# Fetch the public IP address (ensure curl is installed)
if command -v curl >/dev/null 2>&1; then
  PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
else
  PUBLIC_IP="localhost"
fi

##############################################################################
# 4) Pull the Scrapyd Docker image
##############################################################################
echo "Pulling Docker image geeeq2/scrapyd-env..."
docker pull geeeq2/scrapyd-env

echo "Stopping any existing 'scrapyd' container..."
docker stop scrapyd 2>/dev/null || true
docker rm scrapyd 2>/dev/null || true

##############################################################################
# 5) Run the container with a custom command to directly update config
##############################################################################
echo "Starting new Scrapyd container..."
docker run "${DOCKER_ARGS[@]}" --entrypoint "/bin/bash" geeeq2/scrapyd-env -c "sed -i \"s/^username.*/username = $SCRAPYD_USERNAME/\" /etc/scrapyd/scrapyd.conf && sed -i \"s/^password.*/password = $SCRAPYD_PASSWORD/\" /etc/scrapyd/scrapyd.conf && scrapyd --pidfile="

if [ $? -ne 0 ]; then
  echo "Failed to start Scrapyd container. Please check the logs for details."
  exit 1
fi

##############################################################################
# 6) Store credentials if not already stored
##############################################################################

if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "URL: http://${PUBLIC_IP}:6800" > $CREDENTIALS_FILE
  echo "Username: $SCRAPYD_USERNAME" >> $CREDENTIALS_FILE
  echo "Password: $SCRAPYD_PASSWORD" >> $CREDENTIALS_FILE
fi

##############################################################################
# 7) Display info
##############################################################################
# Define color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Show container info
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

# Output the container logs
echo "Container logs:"
docker logs scrapyd