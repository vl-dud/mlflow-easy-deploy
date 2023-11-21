# MLflow Easy Deploy

## Docker Compose Setup for MLflow Tracking Server

This Docker Compose configuration is designed to create a development environment that includes the following services:

- **MLflow Server**: An open-source platform for managing the end-to-end machine learning lifecycle.
- **Minio**: An open-source object storage server compatible with Amazon S3.
- **MySQL**: A popular relational database management system.
- **Ofelia**: A modern and low footprint job scheduler for docker environments.

## Prerequisites

Before using this Docker Compose setup, make sure you have the following prerequisites installed on your system:

- Docker: [Install Docker](https://docs.docker.com/get-docker/)
- Docker Compose: [Install Docker Compose](https://docs.docker.com/compose/install/)

## Usage

1. Clone or download the repository to your local machine.

2. Customize the environment variables in the `.env` file to suit your needs. You can set the following environment variables:

   - `MINIO_PORT`: Port for the Minio server.
   - `MINIO_CONSOLE_PORT`: Port for the MinIO Console.
   - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: Access credentials for Minio.
   - `MYSQL_DATABASE`: Name of the MySQL database.
   - `MYSQL_USER` and `MYSQL_PASSWORD`: MySQL user credentials.
   - `MYSQL_TCP_PORT`: Port for the MySQL database.
   - `MLFLOW_SERVER_PORT`: Port for the MLflow server.

3. Run the following command to start the services defined in the `docker-compose.yml` file:

   ```bash
   docker-compose up -d
   ```
   The -d flag runs the services in detached mode, which means they will run in the background.

4. Once the services are up and running, you can access the following services in a web browser:
   - Minio Console: Open your web browser and navigate to http://localhost:9090 to access the Minio Console (*9090* is your `MINIO_CONSOLE_PORT`). You should use the provided `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for authentication.
   - MLflow Server: Open your web browser and navigate to http://localhost:5000 to access the MLflow Server (*5000* is your `MLFLOW_SERVER_PORT`).

5. To stop and remove the containers, run the following command:
   ```bash
   docker-compose down
   ```

## Additional Notes

- `minio_volume` and `db_volume` volumes are created to persist data for Minio and MySQL, respectively. Data stored in these volumes will be retained across container restarts.
- Health checks and dependencies between services ensure that each service is ready before the next one starts.
- Ofelia job scheduler is used to run `mlflow gc` every 6 hours. `mlflow gc` permanently deletes runs in the *deleted* lifecycle stage.
- `minio_healthcheck` service is used for verifying the status of Minio. Minio is supposed to have no curl. If that's not the case, then add healthcheck to `minio` service:
   ```
   healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${MINIO_PORT}/minio/health/live"]
      timeout: 10s
      retries: 10
   ```

Enjoy using this Docker Compose setup for your development or testing environment!