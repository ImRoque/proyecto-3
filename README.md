# Proyecto 3 — Integración, aplicación web y móvil

**Equipo 5:**
- Daniel Adrián Roque Cortés
- Cesar Figueroa Merino
- Armando Casanova Lemus
- Kelly Merali Rodríguez Reyna
- Annatar Armando Murillo Rivera


**Arquitectura seleccionada:** microservicios con API Gateway. Los clientes web y
móvil (una sola aplicación Flutter) se comunican únicamente con el gateway, que
enruta las solicitudes hacia cada microservicio.

## Estructura

| Carpeta | Propósito |
|---|---|
| `services/catalogo/` | Microservicio de catálogo: medios de entrega y tipos de servicio (Django) |
| `services/pedidos/` | Microservicio de pedidos: registro con folio, consulta y estados (Django) |
| `services/recomendar/` | Microservicio del recomendador — IA 1: modelo `.joblib` + reglas de negocio (Django) |
| `services/asistente/` | Microservicio del asistente — IA 2: clasificador de intenciones `.joblib` (Django) |
| `gateway/` | API Gateway nginx: punto único de entrada para web y móvil |
| `app_flutter/` | Aplicación Flutter web y Android (mismo código) |
| `infra/` | PostgreSQL 16 con una base por servicio |
| `docs/` | Arquitectura, contratos de API, patrones, informes y auditoría |
| `scripts/` | Configuración inicial del repositorio en GitHub |
| `.github/` | CODEOWNERS y plantillas de PR e Issues |

## Cómo empezar a trabajar

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>
git checkout develop
git pull
git checkout -b feature/<area>-<descripcion>
```

Las reglas completas están en [CONTRIBUTING.md](CONTRIBUTING.md).

### Levantar todo el sistema

Requisitos: Docker con Docker Compose v2.

```bash
cp .env.example .env
docker compose up -d --build
```

Esto levanta PostgreSQL, los 4 microservicios y el API Gateway. Solo el gateway queda
publicado, en `http://localhost:8080`; todo pasa por él:

```bash
curl http://localhost:8080/api/catalogo/health/
curl http://localhost:8080/api/pedidos/health/
curl http://localhost:8080/api/recomendar/health/
curl http://localhost:8080/api/asistente/health/
```

Para apagar: `docker compose down` (conserva la base) o `docker compose down -v` (la borra).
Más detalles en [gateway/README.md](gateway/README.md) e [infra/README.md](infra/README.md).

### Compilar la app (web y apk)

Desde `app_flutter/`. La URL del gateway se fija **al compilar** con `--dart-define`; si se
omite, la app usa `http://localhost:8080`, que en un teléfono no funciona.

```bash
flutter build web --dart-define=API_URL=http://localhost:8080
flutter build apk --debug --dart-define=API_URL=http://<IP-de-la-PC>:8080
```

Los pasos completos, la URL por plataforma y por qué el apk es `--debug` están en
[app_flutter/README.md](app_flutter/README.md#compilar-web-y-apk).

## Pendientes de acuerdo del equipo

- [ ] Asignar áreas y responsables (actualizar esta tabla y `.github/CODEOWNERS`)
- [ ] Documentar detalles de la arquitectura seleccionada → `docs/arquitectura.md`
- [ ] Acordar los contratos de API → `docs/api.md`
- [ ] Definir el análisis de patrones → `docs/patrones.md`
- [ ] Definir y crear las tareas reales como Issues
- [ ] Incorporar el CI cuando exista código que probar
- [ ] Antes de un despliegue fuera de clase: limitar CORS del gateway a orígenes conocidos (hoy `*`) → `gateway/nginx.conf`

## Auditoría

Última auditoría: 2026-11-24, `qwen2.5-coder:7b` y `llama3.2` (Ollama, local). Hallazgos
confirmados: CORS abierto en el gateway (baja), README desactualizado y falta del build
web/apk documentado (corregidos). Detalle en [docs/auditoria/hallazgos.md](docs/auditoria/hallazgos.md).
