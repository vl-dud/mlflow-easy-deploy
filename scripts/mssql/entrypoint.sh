#!/bin/bash
set -eu

DB_PORT="${DB_PORT:-1433}"
DB_NAME="${DB_NAME:?DB_NAME is not set}"
DB_USER="${DB_USER:?DB_USER is not set}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is not set}"

/opt/mssql/bin/sqlservr &
SQL_PID=$!

echo "Waiting for SQL Server to start..."
until /opt/mssql-tools18/bin/sqlcmd \
        -S "localhost,${DB_PORT}" -U sa -P "${MSSQL_SA_PASSWORD}" \
        -C -Q "SELECT 1" -b > /dev/null 2>&1; do
    sleep 2
done

echo "Running initialization..."

/opt/mssql-tools18/bin/sqlcmd \
    -S "localhost,${DB_PORT}" -U sa -P "${MSSQL_SA_PASSWORD}" -C \
    -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'${DB_NAME}') CREATE DATABASE [${DB_NAME}]"

/opt/mssql-tools18/bin/sqlcmd \
    -S "localhost,${DB_PORT}" -U sa -P "${MSSQL_SA_PASSWORD}" -C \
    -Q "IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'${DB_USER}') CREATE LOGIN [${DB_USER}] WITH PASSWORD = N'${DB_PASSWORD}'"

/opt/mssql-tools18/bin/sqlcmd \
    -S "localhost,${DB_PORT}" -U sa -P "${MSSQL_SA_PASSWORD}" -C -d "${DB_NAME}" \
    -Q "IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'${DB_USER}') BEGIN CREATE USER [${DB_USER}] FOR LOGIN [${DB_USER}]; ALTER ROLE db_owner ADD MEMBER [${DB_USER}]; END"

touch /var/opt/mssql/.init_done
echo "Initialization complete."

wait $SQL_PID
