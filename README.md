# MLflow Tracking Stack

Docker Compose stack for a local MLflow tracking server: MLflow, MinIO, Ofelia, and a choice of PostgreSQL, MySQL, or SQLite as the backend store.

## What you need

[Docker](https://docs.docker.com/get-docker/) with Compose (`docker compose` or `docker-compose`).

## Services

The stack is split across compose files that are combined at startup.

**Base (`compose.yml`)**

| Service          | Role                                                                                                                        | Depends on           |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| **minio**        | S3-compatible store for MLflow artifacts.                                                                                   | —                    |
| **minio_client** | One-shot bootstrap: configures the MinIO client alias and creates the `mlflow` bucket so the server can use `s3://mlflow/`. | **minio**            |
| **server**       | Custom image running `mlflow server` against the chosen database and MinIO.                                                 | **minio_client**, **backend** |
| **ofelia**       | Scheduler; talks to Docker and runs labeled jobs on the **server** and backup containers.                                   | **server**           |

**Database overlay**

| Overlay                  | Service       | Role                                                                           | Depends on |
| ------------------------ | ------------- | ------------------------------------------------------------------------------ | ---------- |
| `compose.postgres.yml`   | **backend**        | PostgreSQL 17.8 backend store for MLflow metadata.                             | —                   |
|                          | **backend_backup** | Scheduled pg_dump with 7-day retention.                                        | **backend**         |
| `compose.mysql.yml`      | **backend**        | MySQL 8.4 backend store for MLflow metadata.                                   | —                   |
|                          | **backend_backup** | Scheduled mysqldump with 7-day retention.                                      | **backend**         |
| `compose.mssql.yml`      | **backend**        | SQL Server 2022 (Developer edition) backend store for MLflow metadata. Runs DB/user init on first startup via entrypoint script. | — |
|                          | **backend_backup** | Scheduled `BACKUP DATABASE` (.bak) with 7-day retention.                       | **backend**         |
| `compose.sqlite.yml`     | **backend_backup** | Scheduled file copy of the SQLite database with 7-day retention.               | —                   |

Startup order (PostgreSQL / MySQL): **minio** and **backend** start first; **minio_client** bootstraps MinIO; **server** starts after **minio_client** and a healthy **backend**; **ofelia** starts after **server**.

Startup order (MSSQL): same as PostgreSQL/MySQL. The DB/user creation runs inside **backend**'s entrypoint; healthcheck only passes after init is done, so **server** and **backend_backup** start at the right time.

Startup order (SQLite): **minio** and **minio_client** start first; **server** starts after **minio_client** and mounts the SQLite volume; **ofelia** and **backend_backup** start after **server**.

## Environment variables

Defaults match [`.env.example`](.env.example). Change secrets before any shared or production use.

| Name                      | Purpose                                                                                                                                     | Default (PostgreSQL)                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`       | MinIO root user; also passed to MLflow for S3 artifact access.                                                                              | `minio_key`                                                             |
| `AWS_SECRET_ACCESS_KEY`   | MinIO root password; also passed to MLflow for S3 artifact access.                                                                          | `minio_secret`                                                          |
| `MINIO_PORT`              | MinIO S3 API port (host and container).                                                                                                     | `9000`                                                                  |
| `MINIO_CONSOLE_PORT`      | MinIO web console port.                                                                                                                     | `9090`                                                                  |
| `DB_PORT`                 | Database port inside the stack.                                                                                                             | `5432` (PostgreSQL) / `3306` (MySQL)                                    |
| `DB_NAME`                 | Database name for MLflow metadata.                                                                                                          | `mlflow_database`                                                       |
| `DB_USER`                 | Database user for MLflow.                                                                                                                   | `mlflow_user`                                                           |
| `DB_PASSWORD`             | Database password for `DB_USER`.                                                                                                            | `mlflow`                                                                |
| `DB_ROOT_PASSWORD`        | MySQL root password. Required only when using `compose.mysql.yml`.                                                                          | `mlflow_root`                                                           |
| `DB_SA_PASSWORD`          | SQL Server SA password. Required only when using `compose.mssql.yml`. Must meet SQL Server complexity requirements (8+ chars, mixed case, digit, special char). | `Mlflow_SA_P@ss1` |
| `MLFLOW_BACKEND_STORE_URI`| Full SQLAlchemy URI passed to `mlflow server --backend-store-uri`.                                                                          | `postgresql+psycopg2://mlflow_user:mlflow@db:5432/mlflow_database`      |
| `DEFAULT_ARTIFACT_ROOT`   | Passed to `mlflow server --default-artifact-root`; must match the bucket the **minio_client** creates (`mlflow` → `s3://mlflow/`).          | `s3://mlflow/`                                                          |
| `MLFLOW_SERVER_PORT`      | Host port mapped to MLflow UI and API (`5000` in the container).                                                                            | `5000`                                                                  |

## Run it

1. Copy `.env.example` to `.env` and fill in the variables (especially credentials, ports, and `MLFLOW_BACKEND_STORE_URI`).

2. Start with **PostgreSQL**:
   ```bash
   docker compose -f compose.yml -f compose.postgres.yml up -d
   ```

   Start with **MySQL**:
   ```bash
   docker compose -f compose.yml -f compose.mysql.yml up -d
   ```

   Start with **MSSQL**:
   ```bash
   docker compose -f compose.yml -f compose.mssql.yml up -d
   ```

   Start with **SQLite**:
   ```bash
   docker compose -f compose.yml -f compose.sqlite.yml up -d
   ```

3. Open in the browser (ports come from `.env`):
   - MLflow: `http://localhost:<MLFLOW_SERVER_PORT>` (default `5000`)
   - MinIO console: `http://localhost:<MINIO_CONSOLE_PORT>` (default `9090`); log in with `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`

4. Stop:
   ```bash
   docker compose -f compose.yml -f compose.postgres.yml down
   # or
   docker compose -f compose.yml -f compose.mysql.yml down
   # or
   docker compose -f compose.yml -f compose.mssql.yml down
   # or
   docker compose -f compose.yml -f compose.sqlite.yml down
   ```

## Use MLflow from Python

**MinIO bucket:** On startup, the **minio_client** service creates the `mlflow` bucket so the artifact root `s3://mlflow/` exists before MLflow writes artifacts.

Point the client at the tracking server (host port from `MLFLOW_SERVER_PORT`, default `5000`):

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")
```

Or with the environment variable (works for any MLflow client):

```bash
export MLFLOW_TRACKING_URI=http://localhost:5000
```

**Artifacts from the same machine as Compose:** Logging models or files (`mlflow.log_artifact`, `log_model`, etc.) usually requires direct access to MinIO using the same credentials as in `.env` and the **S3 API** port (`MINIO_PORT`, default `9000`). Set these before importing/using artifact APIs:

```python
import os

os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://127.0.0.1:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio_key"  # match .env
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio_secret"
```

If MinIO rejects virtual-hosted-style requests, set `AWS_S3_ADDRESSING_STYLE=path` for boto3.

**Another container on the same Compose network:** use `http://server:5000` for the tracking URI and `http://minio:9000` (with internal `MINIO_PORT`) for `MLFLOW_S3_ENDPOINT_URL`, with the same access key and secret.

## Additional Notes

- MinIO and database volumes persist data across container restarts.
- Health checks and dependencies between services ensure that each service is ready before the next one starts.
- Ofelia runs `mlflow gc` every 24 hours to permanently delete runs in the *deleted* lifecycle stage.
- Database backups run every 12 hours with a 7-day retention window. Use the `restore_backup.sh` script inside the **backend_backup** container to restore a dump.
