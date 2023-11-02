FROM python:3.11-slim-buster
RUN pip install boto3 cryptography mlflow pymysql
