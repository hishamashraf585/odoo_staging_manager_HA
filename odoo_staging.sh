#!/bin/bash

# -------------------------------
# Odoo Staging Manager
# Version: 1.0
# Author: Hisham Ashraf
# -------------------------------

# Configuration
LIVE_DB_HOST="db-host"
LIVE_DB_USER="odoo-prod-user"
LIVE_DB_PASS="prod-password"
DOCKER_NETWORK="odoo-staging-net"
BASE_DIR="/odoo/staging"

# Text Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${YELLOW}Usage:"
    echo -e "  $0 [options]"
    echo -e "\nOptions:"
    echo -e "  --live-db     Live database name (required)"
    echo -e "  --stg-db      Staging database name (required)"
    echo -e "  --port        Staging port (required)"
    echo -e "  --help        Show this help${NC}"
    exit 0
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --live-db) LIVE_DB_NAME="$2"; shift ;;
        --stg-db) STAGING_DB_NAME="$2"; shift ;;
        --port) STAGING_PORT="$2"; shift ;;
        --help) show_help ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; exit 1 ;;
    esac
    shift
done

# Validate inputs
if [[ -z "$LIVE_DB_NAME" || -z "$STAGING_DB_NAME" || -z "$STAGING_PORT" ]]; then
    echo -e "${RED}Error: Missing required parameters!${NC}"
    show_help
fi

# Generate unique staging ID
STAGING_ID="stg-$(date +%Y%m%d%H%M%S)"
STAGING_DIR="${BASE_DIR}/${STAGING_ID}"

# Create directory structure
mkdir -p "${STAGING_DIR}"/{addons,config,data/postgres,filestore,logs}

# Generate Odoo configuration
cat > "${STAGING_DIR}/config/odoo.conf" <<EOL
[options]
admin_passwd = ${STAGING_ID}-secret
db_host = db-${STAGING_ID}
db_user = ${STAGING_ID}-user
db_password = ${STAGING_ID}-pass
db_port = 5432
addons_path = /mnt/extra-addons,/mnt/enterprise
data_dir = /var/lib/odoo
xmlrpc_port = ${STAGING_PORT}
proxy_mode = True
EOL

# Generate Docker Compose file
cat > "${STAGING_DIR}/docker-compose.yml" <<EOL
version: '3.8'
services:
  web-${STAGING_ID}:
    image: odoo:18.0
    container_name: odoo-${STAGING_ID}
    ports:
      - "${STAGING_PORT}:${STAGING_PORT}"
    volumes:
      - ${STAGING_DIR}/addons:/mnt/extra-addons
      - ${STAGING_DIR}/config:/etc/odoo
      - ${STAGING_DIR}/filestore:/var/lib/odoo/filestore
      - ${STAGING_DIR}/logs:/var/log/odoo
    networks:
      - ${DOCKER_NETWORK}
    depends_on:
      - db-${STAGING_ID}

  db-${STAGING_ID}:
    image: postgres:14
    container_name: postgres-${STAGING_ID}
    environment:
      POSTGRES_USER: ${STAGING_ID}-user
      POSTGRES_PASSWORD: ${STAGING_ID}-pass
      POSTGRES_DB: ${STAGING_DB_NAME}
    volumes:
      - ${STAGING_DIR}/data/postgres:/var/lib/postgresql/data
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    driver: bridge
EOL

# Clone live database
echo -e "${BLUE}Cloning live database...${NC}"
PGPASSWORD="$LIVE_DB_PASS" pg_dump -h "$LIVE_DB_HOST" -U "$LIVE_DB_USER" -Fc "$LIVE_DB_NAME" > "${STAGING_DIR}/db.dump"

# Start containers
echo -e "${BLUE}Starting Docker containers...${NC}"
docker-compose -f "${STAGING_DIR}/docker-compose.yml" up -d

# Wait for PostgreSQL to initialize
echo -e "${BLUE}Waiting for database to initialize...${NC}"
sleep 20

# Restore database
echo -e "${BLUE}Restoring database...${NC}"
docker exec -i postgres-${STAGING_ID} pg_restore -U "${STAGING_ID}-user" -d "$STAGING_DB_NAME" < "${STAGING_DIR}/db.dump"

# Cleanup
rm "${STAGING_DIR}/db.dump"

# Create management script
cat > "${STAGING_DIR}/manage.sh" <<EOL
#!/bin/bash
case "\$1" in
    start)
        docker-compose -f "${STAGING_DIR}/docker-compose.yml" up -d
        ;;
    stop)
        docker-compose -f "${STAGING_DIR}/docker-compose.yml" stop
        ;;
    restart)
        docker-compose -f "${STAGING_DIR}/docker-compose.yml" restart
        ;;
    remove)
        docker-compose -f "${STAGING_DIR}/docker-compose.yml" down -v
        rm -rf "${STAGING_DIR}"
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|remove}"
esac
EOL

chmod +x "${STAGING_DIR}/manage.sh"

# Final output
echo -e "${GREEN}Staging environment created successfully!${NC}"
echo -e "Access URL: ${YELLOW}http://your-server:${STAGING_PORT}${NC}"
echo -e "Management script: ${YELLOW}${STAGING_DIR}/manage.sh${NC}"
echo -e "Database credentials:"
echo -e "  User: ${YELLOW}${STAGING_ID}-user${NC}"
echo -e "  Pass: ${YELLOW}${STAGING_ID}-pass${NC}"
echo -e "  DB Name: ${YELLOW}${STAGING_DB_NAME}${NC}"
