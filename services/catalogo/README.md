# services/catalogo

**Propósito:** microservicio responsable del catálogo que la aplicación permitirá explorar y buscar.

## Contenido previsto (pendiente de acuerdo)

- Modelo de datos del catálogo
- Endpoints de consulta y búsqueda
- Datos de prueba
- Pruebas


## Estado actual

Servicio Django 5 (proyecto `config`, app `catalogo`) con las rutas de `docs/api.md`:

| Método | Ruta | Respuesta |
|---|---|---|
| `GET` | `/api/catalogo/health/` | `{"servicio": "catalogo", "ok": true}` |
| `GET` | `/api/catalogo/medios/?q=<texto>` | `{"medios": [...], "total": N}`. `q` es opcional, busca en `nombre` y `descripcion` sin distinguir mayúsculas ni acentos; más de 100 caracteres da `400 datos_invalidos`. |
| `GET` | `/api/catalogo/medios/<clave>/` | El medio, o `404 no_encontrado`. |
| `GET` | `/api/catalogo/tipos-servicio/` | `{"tipos_servicio": [...], "total": N}` |

Rutas inexistentes, o un método distinto de `GET`, responden `404 ruta_no_encontrada`.
Todos los errores usan el formato `{"error": "<codigo>", "detalle": "<texto>"}`.

### Organización del código

| Archivo | Qué contiene |
|---|---|
| `catalogo/models.py` | Modelos `MedioEntrega` y `TipoServicio`. |
| `catalogo/repositorio.py` | Acceso a datos (patrón Repository). Las vistas no usan el ORM. |
| `catalogo/views.py` | Validación de la petición y armado de la respuesta. |
| `catalogo/errores.py` | Respuestas JSON y formato único de error. |
| `catalogo/fixtures/catalogo_inicial.json` | Datos de prueba: 4 medios y 3 tipos de servicio. |
| `entrypoint.sh` | Arranque en Docker: `migrate`, `loaddata` y gunicorn. |

### Datos de prueba

Los límites de peso y distancia coinciden con las reglas R1 y R2 de `recomendar` en
`docs/api.md`. En Docker se cargan solos al arrancar; `loaddata` se puede repetir sin
duplicar porque cada registro tiene `pk` fija.

## Variables de entorno

| Variable | Uso | Por defecto |
|---|---|---|
| `SECRET_KEY` | Clave de Django | Valor de desarrollo (cámbiala fuera de tu equipo) |
| `DEBUG` | `True` o `False` | `False` |
| `ALLOWED_HOSTS` | Hosts permitidos, separados por coma | `localhost,127.0.0.1` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` | PostgreSQL | Si no hay `DB_NAME`, usa SQLite |

Ver `.env.example`.

## Correrlo solo (sin Docker)

Desde `services/catalogo/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py loaddata catalogo_inicial.json
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/catalogo/health/
curl -i "http://localhost:8000/api/catalogo/medios/?q=moto"
```

## Correrlo con Docker

Desde `services/catalogo/`:

```bash
docker build -t proyecto3-catalogo .
docker run --rm -p 8000:8000 proyecto3-catalogo
```

```bash
curl -i http://localhost:8000/api/catalogo/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=catalogo,localhost`.

## Pruebas

Desde `services/catalogo/`, con las dependencias instaladas:

```bash
python manage.py test
```
