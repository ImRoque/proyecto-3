#!/bin/bash
# Crea una base de datos y un usuario por servicio (docs/arquitectura.md, seccion 5.2).
#
# Lo ejecuta la imagen oficial de PostgreSQL desde /docker-entrypoint-initdb.d/
# SOLO la primera vez, cuando el volumen de datos esta vacio. Para volver a
# ejecutarlo hay que borrar el volumen: docker compose down -v
#
# Cada servicio tiene su propio usuario, dueno unicamente de su base. Ningun
# usuario puede conectarse a la base de otro servicio.
#
# Las contrasenas llegan por variables de entorno: <SERVICIO>_DB_PASSWORD
# (por ejemplo CATALOGO_DB_PASSWORD). Ver .env.example en la raiz.
set -euo pipefail

SERVICIOS="catalogo pedidos recomendar asistente"

for servicio in $SERVICIOS; do
    variable="${servicio^^}_DB_PASSWORD"
    password="${!variable:-}"
    if [ -z "$password" ]; then
        echo "Falta la variable $variable" >&2
        exit 1
    fi

    echo "Creando usuario y base de datos: $servicio"
    psql -v ON_ERROR_STOP=1 \
        --username "$POSTGRES_USER" \
        --dbname "$POSTGRES_DB" \
        --set=servicio="$servicio" \
        --set=password="$password" <<-'EOSQL'
		CREATE ROLE :"servicio" WITH LOGIN PASSWORD :'password';
		CREATE DATABASE :"servicio" OWNER :"servicio";
		REVOKE ALL ON DATABASE :"servicio" FROM PUBLIC;
	EOSQL
done

echo "Bases de datos por servicio creadas."
