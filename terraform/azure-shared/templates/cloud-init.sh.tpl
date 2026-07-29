#!/bin/bash

# Log everything to a file for debugging
exec > >(tee -a /var/log/postgres-setup.log)
exec 2>&1

set -euo pipefail

echo "================================================"
echo "PostgreSQL Workshop Instance Setup Started"
echo "Script PID: $$"
echo "Start Time: $(date)"
echo "================================================"

START_TIME=$(date +%s)

# Update system
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y || echo "WARNING: apt-get upgrade failed, continuing..."

# Install Docker
echo "Installing Docker..."
apt-get install -y docker.io docker-compose-v2
systemctl enable docker
systemctl start docker

docker --version
systemctl status docker --no-pager

# Create directory for PostgreSQL data and init scripts
echo "Creating PostgreSQL directories..."
mkdir -p /opt/postgres/data
mkdir -p /opt/postgres/init-scripts
chmod -R 777 /opt/postgres

# Create PostgreSQL initialization script
echo "Creating PostgreSQL init script..."
cat > /opt/postgres/init-scripts/01-init.sql <<'INIT_SQL'
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
    created_at BIGINT,
    updated_at BIGINT
);

CREATE TABLE IF NOT EXISTS riverpay.fx_rates (
    currency_code VARCHAR(3) PRIMARY KEY,
    rate_to_usd DOUBLE PRECISION NOT NULL,
    updated_at BIGINT NOT NULL
);

INSERT INTO riverpay.fx_rates (currency_code, rate_to_usd, updated_at) VALUES
    ('USD', 1.0000, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('GBP', 1.2700, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('AUD', 0.6550, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('CAD', 0.7350, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('JPY', 0.00670, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('EUR', 1.0850, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT)
ON CONFLICT (currency_code) DO NOTHING;

CREATE USER debezium WITH REPLICATION LOGIN PASSWORD '${debezium_password}';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO debezium;
GRANT ALL PRIVILEGES ON SCHEMA riverpay TO debezium;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA riverpay TO debezium;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA riverpay TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA riverpay GRANT ALL PRIVILEGES ON TABLES TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA riverpay GRANT ALL PRIVILEGES ON SEQUENCES TO debezium;

ALTER TABLE riverpay.customer_profiles OWNER TO debezium;
ALTER TABLE riverpay.fx_rates OWNER TO debezium;

GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER USER debezium WITH REPLICATION;

CREATE PUBLICATION dbz_publication FOR TABLES IN SCHEMA riverpay;

\echo 'PostgreSQL initialization complete'
\echo 'Database: ${db_name}'
\echo 'Schema: riverpay (customer_profiles, fx_rates)'
\echo 'CDC User: debezium'
\echo 'Publication: dbz_publication (FOR TABLES IN SCHEMA riverpay)'
INIT_SQL

# Create docker-compose.yml file
cat > /opt/postgres/docker-compose.yml <<'DOCKER_COMPOSE'
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
      test: ["CMD-SHELL", "pg_isready -U ${db_username}"]
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
docker compose up -d

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL to become healthy..."
MAX_RETRIES=60
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
  STATUS=$(docker inspect -f '{{.State.Health.Status}}' postgres-workshop 2>/dev/null || echo "not_ready")
  if [ "$STATUS" = "healthy" ]; then
    echo "PostgreSQL is healthy!"
    break
  fi
  COUNT=$((COUNT + 1))
  echo "  Attempt $COUNT/$MAX_RETRIES (status: $STATUS) - waiting 10s..."
  sleep 10
done

if [ $COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: PostgreSQL did not become healthy after 10 minutes"
  exit 1
fi

HEALTHY_TIME=$(date +%s)
ELAPSED=$((HEALTHY_TIME - START_TIME))
echo "================================================"
echo "PostgreSQL is healthy! Time to healthy: $ELAPSED seconds"
echo "================================================"

# Verify setup
echo "Verifying PostgreSQL setup..."
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SELECT version();"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SHOW wal_level;"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SELECT * FROM pg_publication;"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "\dn"

echo "Verifying Debezium CDC user..."
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "\du debezium"

# Mark setup as complete
touch /opt/postgres/.setup-complete

END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))
echo "================================================"
echo "PostgreSQL workshop instance setup complete!"
echo "Total Duration: $TOTAL_ELAPSED seconds"
echo "================================================"

exit 0
