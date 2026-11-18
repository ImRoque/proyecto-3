# services/asistente

**Propósito:** microservicio del asistente para el comprador (IA 2), entrenado con datos propios.


## Contenido previsto (pendiente de acuerdo)

- Dataset de intenciones o pares pregunta-respuesta
- Script de entrenamiento, artefacto y métrica
- Endpoint de conversación
- Integración con otros servicios sin romper el borde de entrada
- Pruebas

## Estado actual

Esqueleto Django 5 (proyecto `config`, app `asistente`). Por ahora solo expone la ruta
de salud definida en `docs/api.md`:

```
GET /api/asistente/health/  ->  200  {"servicio": "asistente", "ok": true}
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

Desde `services/asistente/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/asistente/health/
```

## Correrlo con Docker

Desde `services/asistente/`:

```bash
docker build -t proyecto3-asistente .
docker run --rm -p 8000:8000 proyecto3-asistente
```

```bash
curl -i http://localhost:8000/api/asistente/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=asistente,localhost`.

## Pruebas

Desde `services/asistente/`, con las dependencias instaladas:

```bash
python manage.py test
```
