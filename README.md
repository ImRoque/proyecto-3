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
| `services/catalogo/` | Microservicio de catálogo (pendiente) |
| `services/pedidos/` | Microservicio de pedidos (pendiente) |
| `services/recomendar/` | Microservicio del recomendador — IA 1 (pendiente) |
| `services/asistente/` | Microservicio del asistente — IA 2 (pendiente) |
| `gateway/` | API Gateway: punto único de entrada para web y móvil (pendiente) |
| `app_flutter/` | Aplicación Flutter web y Android (pendiente) |
| `infra/` | Infraestructura y entorno local (pendiente) |
| `docs/` | Arquitectura, contratos de API, patrones e informes (plantillas) |
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

## Pendientes de acuerdo del equipo

- [ ] Asignar áreas y responsables (actualizar esta tabla y `.github/CODEOWNERS`)
- [ ] Documentar detalles de la arquitectura seleccionada → `docs/arquitectura.md`
- [ ] Acordar los contratos de API → `docs/api.md`
- [ ] Definir el análisis de patrones → `docs/patrones.md`
- [ ] Definir y crear las tareas reales como Issues
- [ ] Incorporar el CI cuando exista código que probar
