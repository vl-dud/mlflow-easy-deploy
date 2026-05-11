# MLflow Tracking Stack

Docker Compose stack for a local MLflow tracking server: MLflow, MinIO, Ofelia, and a choice of PostgreSQL, MySQL, MSSQL, or SQLite as the backend store. Requires [Docker](https://docs.docker.com/get-docker/) with Compose.

## Services

The stack combines a base file with a database overlay.

**Base (`compose.yml`)**

| Service          | Role                                                                 |
| ---------------- | -------------------------------------------------------------------- |
| **minio**        | S3-compatible artifact store.                                        |
| **minio_client** | One-shot bootstrap: creates the `mlflow` bucket in MinIO.            |
| **server**       | `mlflow server` connected to MinIO and the chosen database.          |
| **ofelia**       | Scheduler that runs `mlflow gc` and backup jobs via Docker labels.   |

**Backend overlays**

| Overlay                | Services                              | Role                                                    |
| ---------------------- | ------------------------------------- | ------------------------------------------------------- |
| `compose.postgres.yml` | **backend**, **backend_backup**       | PostgreSQL 17 backend with `pg_dump` backups.           |
| `compose.mysql.yml`    | **backend**, **backend_backup**       | MySQL 8.4 backend with `mysqldump` backups.             |
| `compose.mssql.yml`    | **backend**, **backend_backup**       | SQL Server 2022 Dev backend with `.bak` backups.        |
| `compose.sqlite.yml`   | **backend_backup**                    | SQLite file-volume backend with file-copy backups.      |

Services start in dependency order; health checks gate each stage.

## Environment variables

Copy `.env.example` to `.env` and adjust before first run. Change all secrets before any shared or production use.

| Name                      | Purpose                                                                               | Default                                                            |
| ------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `AWS_ACCESS_KEY_ID`       | MinIO root user / S3 access key for MLflow.                                           | `minio_key`                                                        |
| `AWS_SECRET_ACCESS_KEY`   | MinIO root password / S3 secret for MLflow.                                           | `minio_secret`                                                     |
| `MINIO_PORT`              | MinIO S3 API port.                                                                    | `9000`                                                             |
| `MINIO_CONSOLE_PORT`      | MinIO web console port.                                                               | `9090`                                                             |
| `DB_PORT`                 | Database port inside the stack.                                                       | `5432`                                                    |
| `DB_NAME`                 | MLflow metadata database name.                                                        | `mlflow_database`                                                  |
| `DB_USER`                 | MLflow database user.                                                                 | `mlflow_user`                                                      |
| `DB_PASSWORD`             | Password for `DB_USER`.                                                               | `mlflow`                                                           |                                               |
| `MLFLOW_BACKEND_STORE_URI`| SQLAlchemy URI for `mlflow server --backend-store-uri`.                               | Depends on the database |
| `DEFAULT_ARTIFACT_ROOT`   | Artifact root; must match the bucket created by **minio_client**.                     | `s3://mlflow/`                                                     |
| `MLFLOW_SERVER_PORT`      | Host port for the MLflow UI/API.                                                      | `5000`                                                             |

## Run

Pick a database backend and pass both compose files:

```bash
# PostgreSQL
docker compose -f compose.yml -f compose.postgres.yml up -d

# MySQL
docker compose -f compose.yml -f compose.mysql.yml up -d

# MSSQL
docker compose -f compose.yml -f compose.mssql.yml up -d

# SQLite
docker compose -f compose.yml -f compose.sqlite.yml up -d
```

Open in the browser (ports from `.env`):
- MLflow UI: `http://localhost:5000`
- MinIO console: `http://localhost:9090` — log in with `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`

Stop with the same `-f` flags:

```bash
docker compose -f compose.yml -f compose.postgres.yml down
```

## Use MLflow from Python

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")
```

Logging artifacts also requires direct MinIO access:

```python
import os

os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://127.0.0.1:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio_key"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio_secret"
```

If MinIO rejects virtual-hosted-style requests, also set `AWS_S3_ADDRESSING_STYLE=path`.

**From another container on the same Compose network:** use `http://server:5000` and `http://minio:9000`.

## Notes

- MinIO and database volumes persist across restarts.
- Ofelia runs `mlflow gc` every 24 hours to purge deleted runs.
- Database backups run every 12 hours. Use `restore_backup.sh` inside **backend_backup** to restore a dump.
