# services/pedidos

**Propósito:** microservicio responsable de registrar pedidos y consultarlos por folio.



## Contenido previsto (pendiente de acuerdo)

- Modelo de datos del pedido y sus estados
- Registro y consulta por folio
- Pruebas


## Estado actual

Esqueleto Django 5 (proyecto `config`, app `pedidos`). Por ahora solo expone la ruta
de salud definida en `docs/api.md`:

```
GET /api/pedidos/health/  ->  200  {"servicio": "pedidos", "ok": true}
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

Desde `services/pedidos/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/pedidos/health/
```

## Correrlo con Docker

Desde `services/pedidos/`:

```bash
docker build -t proyecto3-pedidos .
docker run --rm -p 8000:8000 proyecto3-pedidos
```

```bash
curl -i http://localhost:8000/api/pedidos/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=pedidos,localhost`.

## Pruebas

Desde `services/pedidos/`, con las dependencias instaladas:

```bash
python manage.py test
```
