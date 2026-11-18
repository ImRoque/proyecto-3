# services/recomendar

**Propósito:** microservicio del recomendador (IA 1): modelo entrenado y reglas de negocio adaptados al tema.


## Contenido previsto (pendiente de acuerdo)

- Dataset y script de entrenamiento (fuera de la petición HTTP)
- Artefacto del modelo y métrica
- Reglas que pueden corregir al modelo
- Endpoint de recomendación
- Pruebas


## Estado actual

Esqueleto Django 5 (proyecto `config`, app `recomendar`). Por ahora solo expone la ruta
de salud definida en `docs/api.md`:

```
GET /api/recomendar/health/  ->  200  {"servicio": "recomendar", "ok": true}
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

Desde `services/recomendar/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/recomendar/health/
```

## Correrlo con Docker

Desde `services/recomendar/`:

```bash
docker build -t proyecto3-recomendar .
docker run --rm -p 8000:8000 proyecto3-recomendar
```

```bash
curl -i http://localhost:8000/api/recomendar/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=recomendar,localhost`.

## Pruebas

Desde `services/recomendar/`, con las dependencias instaladas:

```bash
python manage.py test
```
