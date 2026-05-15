#!/bin/sh

echo "Esperando a que MySQL esté disponible en $DB_ENDPOINT:$DB_PORT ..."

until nc -z "$DB_ENDPOINT" "$DB_PORT" 2>/dev/null; do
  echo "Base de datos no disponible aún, reintentando en 5s..."
  sleep 5
done

echo "MySQL responde en $DB_ENDPOINT:$DB_PORT — iniciando Spring Boot (backend-ventas)..."
exec java -jar app.jar