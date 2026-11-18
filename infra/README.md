# infra

**Propósito:** infraestructura de soporte y configuración del entorno local de los microservicios.

La orquestación está en el [`docker-compose.yml`](../docker-compose.yml) de la raíz, para que
todo se levante con un solo comando desde ahí.

## Contenido

| Archivo | Uso |
|---|---|
| `postgres/01-crear-bases.sh` | Crea un usuario y una base por servicio al iniciar PostgreSQL por primera vez. |
| `.gitattributes` | Fuerza fin de línea LF en los `.sh`, para que funcionen aunque se clone en Windows. |

## Contenedores

| Contenedor | Imagen | Puerto en el anfitrión | Notas |
|---|---|---|---|
| `postgres` | `postgres:16-alpine` | ninguno | Volumen `pgdata`. Healthcheck con `pg_isready`. |
| `catalogo`, `pedidos`, `recomendar`, `asistente` | se construyen desde `services/<servicio>` | ninguno | Escuchan en `8000` interno. Arrancan cuando PostgreSQL está sano. |
| `gateway` | `nginx:1.27-alpine` | `8080` | Ver [gateway/README.md](../gateway/README.md). |

## Persistencia

Un solo PostgreSQL 16 con una base por servicio (`docs/arquitectura.md`, sección 5.2):

| Base | Usuario | Contraseña (variable en `.env`) |
|---|---|---|
| `catalogo` | `catalogo` | `CATALOGO_DB_PASSWORD` |
| `pedidos` | `pedidos` | `PEDIDOS_DB_PASSWORD` |
| `recomendar` | `recomendar` | `RECOMENDAR_DB_PASSWORD` |
| `asistente` | `asistente` | `ASISTENTE_DB_PASSWORD` |

- Cada usuario es dueño solo de su base y no tiene permiso `CONNECT` sobre las demás.
- Compose pasa a cada servicio `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST=postgres` y `DB_PORT`.
- El script de `postgres/` **solo corre cuando el volumen está vacío**. Si cambias el script o
  las contraseñas, borra el volumen (se pierden los datos locales):

  ```bash
  docker compose down -v
  docker compose up -d --build
  ```

- Las migraciones de Django no se ejecutan al arrancar (los esqueletos aún no tienen modelos).
  Cuando un servicio las tenga: `docker compose exec <servicio> python manage.py migrate`.

## Variables de entorno

Todas están en [`.env.example`](../.env.example) con valores de ejemplo. Copia el archivo como
`.env`; Compose se niega a arrancar si falta alguna contraseña o `SECRET_KEY`.
`.env` está en `.gitignore` y nunca se sube.

## Comandos útiles

```bash
docker compose ps                     # estado de los contenedores
docker compose logs -f gateway        # logs de un contenedor
docker compose stop <servicio>        # apagar un servicio (demo de fallo parcial)
docker compose start <servicio>       # volver a levantarlo
docker compose down                   # apagar todo (conserva la base)
docker compose exec postgres psql -U postgres   # consola de PostgreSQL
```
