FROM python:3.11-slim
RUN apt-get update && apt-get install -y g++

WORKDIR /app


COPY . .
EXPOSE 5432
CMD ["python","main.py"]