
docker cp ./backup.sql postgresdb_database:/backup.sql

docker exec -i postgresdb_database bash -c "psql -U postgres  defaultdb < /backup.sql"

