FROM python:3.14-slim
RUN pip install --no-cache-dir \
    boto3 \
	cryptography \
    mlflow \
    psycopg2-binary