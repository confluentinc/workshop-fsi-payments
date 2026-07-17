#!/bin/bash

# Log everything to a file for debugging
exec > >(tee -a /var/log/postgres-setup.log)
exec 2>&1

# Set error handling
set -euo pipefail

echo "================================================"
echo "PostgreSQL Workshop Instance Setup Started"
echo "Script PID: $$"
echo "Start Time: $(date)"
echo "================================================"

# ===============================
# START TIMING
# ===============================
START_TIME=$(date +%s)

# Update system (with retry logic)
echo "Updating system packages..."
dnf update -y || {
  echo "WARNING: dnf update failed, continuing anyway..."
}

# Install Docker
echo "Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker

# Verify Docker is running
echo "Verifying Docker installation..."
docker --version
systemctl status docker --no-pager

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Create directory for PostgreSQL data and init scripts
echo "Creating PostgreSQL directories..."
mkdir -p /opt/postgres/data
mkdir -p /opt/postgres/init-scripts
chmod -R 777 /opt/postgres

# Create PostgreSQL initialization script
echo "Creating PostgreSQL init script..."
cat > /opt/postgres/init-scripts/01-init.sql <<'INIT_SQL'
-- RiverPay customer profiles schema (CDC source of truth)
CREATE SCHEMA IF NOT EXISTS riverpay;

CREATE TABLE IF NOT EXISTS riverpay.customer_profiles (
    customer_id VARCHAR(50) PRIMARY KEY,
    partner_bank_id VARCHAR(50),
    segment VARCHAR(50),
    account_tier VARCHAR(50),
    home_currency VARCHAR(3),
    country VARCHAR(2),
    full_name VARCHAR(255),
    tax_id VARCHAR(64),
    date_of_birth VARCHAR(10),
    -- Epoch millis (ShadowTraffic `_gen: now`); Flink watermark uses $rowtime
    created_at BIGINT,
    updated_at BIGINT
);

-- Create CDC user with REPLICATION for Debezium
CREATE USER debezium WITH REPLICATION LOGIN PASSWORD '${debezium_password}';

GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO debezium;
GRANT ALL PRIVILEGES ON SCHEMA riverpay TO debezium;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA riverpay TO debezium;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA riverpay TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA riverpay GRANT ALL PRIVILEGES ON TABLES TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA riverpay GRANT ALL PRIVILEGES ON SEQUENCES TO debezium;

-- Transfer ownership for filtered publication
ALTER TABLE riverpay.customer_profiles OWNER TO debezium;

GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER USER debezium WITH REPLICATION;

CREATE PUBLICATION dbz_publication FOR TABLES IN SCHEMA riverpay;

\echo 'PostgreSQL initialization complete'
\echo 'Database: ${db_name}'
\echo 'Schema: riverpay'
\echo 'Table: riverpay.customer_profiles'
\echo 'CDC User: debezium'
\echo 'Publication: dbz_publication (FOR TABLES IN SCHEMA riverpay)'
INIT_SQL

# Create docker-compose.yml file
cat > /opt/postgres/docker-compose.yml <<'DOCKER_COMPOSE'
version: '3.8'
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres-workshop
    environment:
      POSTGRES_PASSWORD: ${db_password}
      POSTGRES_DB: ${db_name}
      POSTGRES_USER: ${db_username}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    command:
      - "postgres"
      - "-c"
      - "wal_level=logical"
      - "-c"
      - "max_replication_slots=${max_replication_slots}"
      - "-c"
      - "max_wal_senders=${max_wal_senders}"
      - "-c"
      - "max_connections=${max_connections}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
DOCKER_COMPOSE

# Start PostgreSQL container
echo "Starting PostgreSQL container..."
cd /opt/postgres
docker-compose up -d

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL to become healthy (this may take 2-3 minutes)..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' postgres-workshop 2>/dev/null)" == "healthy" ]; do
  echo -n "."
  sleep 5
done
echo ""
HEALTHY_TIME=$(date +%s)
ELAPSED=$((HEALTHY_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
echo "================================================"
echo "PostgreSQL is healthy!"
echo "Time to healthy: $ELAPSED seconds ($ELAPSED_MIN minutes)"
echo "================================================"

# Verify setup
echo "Verifying PostgreSQL setup..."
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "SELECT version();"
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "SHOW wal_level;"
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "SELECT * FROM pg_publication;"
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "\dn"

# Verify Debezium user setup
echo ""
echo "Verifying Debezium CDC user setup..."
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "\du debezium"
docker exec postgres-workshop psql -U postgres -d ${db_name} -c "SELECT datname, has_database_privilege('debezium', datname, 'CONNECT') as can_connect FROM pg_database WHERE datname = '${db_name}';"
echo "Debezium user verification complete."

echo ""
echo "Note: Tables will be created by the data generator on first run"

# Set up a welcome message
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
cat > /etc/motd <<MOTD_EOF
╔═══════════════════════════════════════════════════════════╗
║          PostgreSQL 16 Workshop Instance Ready            ║
╚═══════════════════════════════════════════════════════════╝

Connection Details:
  Hostname:  $PUBLIC_HOSTNAME
  Port:      5432
  Database:  ${db_name}
  Username:  ${db_username}
  Password:  ${db_password}

CDC Configuration:
  Debezium User:  debezium
  Publication:    dbz_publication
  WAL Level:      logical

Tables:
  - riverpay.customer_profiles

Container Management:
  Status:     docker ps
  Logs:       docker logs -f postgres-workshop
  Shell:      docker exec -it postgres-workshop psql -U postgres -d ${db_name}
  Restart:    cd /opt/postgres && docker-compose restart
  Stop:       cd /opt/postgres && docker-compose stop

For more info: /opt/postgres/
MOTD_EOF

# ===============================
# END TIMING
# ===============================
END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))
TOTAL_MIN=$((TOTAL_ELAPSED / 60))

echo "================================================"
echo "PostgreSQL workshop instance setup complete!"
echo "End Time: $(date)"
echo "Total Duration: $TOTAL_ELAPSED seconds ($TOTAL_MIN minutes)"
echo "================================================"
echo ""
echo "TIMING SUMMARY:"
echo "  - PostgreSQL Healthy: $ELAPSED seconds ($ELAPSED_MIN minutes)"
echo "  - Total Setup: $TOTAL_ELAPSED seconds ($TOTAL_MIN minutes)"
echo ""

# Write timing to a dedicated file for easy retrieval
cat > /opt/postgres/setup-timing.txt <<TIMING_EOF
PostgreSQL Workshop Setup Timing
=================================
Start Time: $(date -d @$START_TIME)
PostgreSQL Healthy: $ELAPSED seconds ($ELAPSED_MIN minutes)
Setup Complete: $(date -d @$END_TIME)
Total Duration: $TOTAL_ELAPSED seconds ($TOTAL_MIN minutes)
TIMING_EOF

# Mark setup as complete
touch /opt/postgres/.setup-complete

echo "================================================"
echo "Setup script completed successfully!"
echo "Check /var/log/postgres-setup.log for full logs"
echo "================================================"

exit 0
