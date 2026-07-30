#!/bin/bash
# Bind-mounted into the 'db' container at /docker-entrypoint-initdb.d/ — runs
# once, on first init of an empty Postgres data directory, to create the
# non-root user n8n actually connects as. Copied verbatim from the official
# n8n-io/n8n-hosting repo (docker-compose/withPostgres/init-data.sh):
# https://github.com/n8n-io/n8n-hosting/blob/main/docker-compose/withPostgres/init-data.sh
set -e

if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
		GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi
