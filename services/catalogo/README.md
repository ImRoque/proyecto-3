# services/catalogo

**Propósito:** microservicio responsable del catálogo que la aplicación permitirá explorar y buscar.

## Contenido previsto (pendiente de acuerdo)

- Modelo de datos del catálogo
- Endpoints de consulta y búsqueda
- Datos de prueba
- Pruebas


## Estado actual

Esqueleto Django 5 (proyecto `config`, app `catalogo`). Por ahora solo expone la ruta
de salud definida en `docs/api.md`:

```
GET /api/catalogo/health/  ->  200  {"servicio": "catalogo", "ok": true}
```

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
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/catalogo/health/
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
