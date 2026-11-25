# Paquete de contexto para la auditoría con IA

Este archivo se pega tal cual en la IA (Ollama, Gemini AI Studio, HuggingChat…).
No contiene secretos: las claves reales viven en `.env`, que no se versiona.
Antes de pegarlo, confirmen con `git status` que no agregaron nada sensible.

Si el modelo local se queda sin memoria, peguen primero las secciones 1 a 4 y después
los fragmentos de la sección 5 uno por uno.

---

## PROMPT (copiar desde aquí)

Eres revisor de un proyecto universitario (Django + Flutter, gateway nginx, recomendador .joblib + asistente).

Tareas:

1. Lista hallazgos numerados. Cada uno: severidad (alta/media/baja), archivo o módulo sospechoso, evidencia en el texto que te di, riesgo si es cierto, y cómo lo verificaría un humano en 5 minutos.
2. Separa «hecho con evidencia» de «hipótesis sin evidencia».
3. Señala contradicciones con un enunciado que exige: modelo en servidor, mismo front web/móvil, sin secretos en el repo.
4. No reescribas el proyecto. No inventes archivos que no mencioné. Solo puedes citar lo que aparece abajo.
5. Cierra con las 5 comprobaciones manuales más útiles antes de la demo.

---

## 1. Dominio

Servicio de paquetería. El usuario:

- explora un catálogo de medios de entrega (moto, dron, etc.) y tipos de servicio;
- registra un envío y recibe un folio con formato `PQ-AAAAMMDD-XXXX`;
- rastrea su pedido por folio;
- pide una recomendación del medio de entrega según peso, distancia, dimensiones y urgencia (IA 1: clasificador entrenado y guardado en `.joblib`, corregido por reglas de negocio);
- conversa con un asistente (IA 2: clasificador de intenciones `.joblib`) que consulta pedidos y recomendar.

## 2. Arquitectura

- Microservicios Django independientes: `catalogo`, `pedidos`, `recomendar`, `asistente`. Cada uno tiene su propia base PostgreSQL 16, en un contenedor compartido.
- API Gateway nginx: es el único puerto publicado (`8080` en el host → `80` en el contenedor). Enruta `/api/<servicio>/` a `<servicio>:8000`, maneja CORS y tiempos límite (3 s para conectar, 10 s para leer) y responde `503 servicio_no_disponible` si un servicio cae.
- `pedidos` llama por HTTP a `catalogo`. `asistente` llama por HTTP a `pedidos` y a `recomendar`.
- Los modelos `.joblib` se entrenan **al construir la imagen Docker** (`RUN python -m entrenamiento.entrenar`), no en cada petición, y no se versionan en Git.
- App Flutter con un solo código para web y Android. Solo conoce la URL del gateway, que recibe por `--dart-define=API_URL=...` (por defecto `http://localhost:8080`).
- Todo se levanta con `docker compose up -d --build`. Las variables de entorno salen de `.env`, a partir de `.env.example`.
- Formato de error único: `{"error": "<codigo>", "detalle": "<texto>"}`.

## 3. Endpoints (todos a través del gateway)

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/<servicio>/health/` | Salud de cada servicio: `{"servicio": ..., "ok": true}` |
| GET | `/api/catalogo/medios/?q=<texto>` | Lista o busca medios de entrega |
| GET | `/api/catalogo/medios/<clave>/` | Detalle de un medio |
| GET | `/api/catalogo/tipos-servicio/` | Lista los tipos de servicio |
| POST | `/api/pedidos/` | Registra un pedido (encabezado `Idempotency-Key` obligatorio) |
| GET | `/api/pedidos/<folio>/` | Consulta un pedido por folio |
| PATCH | `/api/pedidos/<folio>/estado/` | Cambia el estado de un pedido |
| POST | `/api/recomendar/` | Recomienda un medio: `peso_kg`, `distancia_km`, `dimensiones_cm`, `urgente` |
| POST | `/api/asistente/` | Chat: `{"mensaje": "..."}` |

## 4. Árbol de carpetas (resumido)

```
proyecto-3/
├── docker-compose.yml          # postgres, catalogo, pedidos, recomendar, asistente, gateway
├── .env.example                # valores de relleno; el .env real está en .gitignore
├── gateway/nginx.conf
├── infra/postgres/01-crear-bases.sh
├── services/
│   ├── catalogo/catalogo/      # models, repositorio.py, views.py, fixtures/
│   ├── pedidos/pedidos/        # confirmacion.py, repositorio.py, folio.py, estados.py,
│   │                           # cliente_catalogo.py, validacion.py, views.py
│   ├── recomendar/
│   │   ├── datasets/envios.csv
│   │   ├── entrenamiento/      # generar_dataset.py, entrenar.py
│   │   └── recomendar/         # modelo.py, reglas.py, recomendacion.py, validacion.py, views.py
│   └── asistente/
│       ├── datasets/intenciones.csv
│       ├── entrenamiento/entrenar.py
│       └── asistente/          # modelo.py, extraccion.py, conversacion.py, adaptador.py,
│                               # clientes.py, views.py
├── app_flutter/lib/
│   ├── config.dart             # API_URL por --dart-define
│   ├── services/               # api_client.dart, aviso_error.dart, idempotencia.dart
│   ├── models/                 # medio_entrega, pedido, tipo_servicio, mensaje_chat
│   └── screens/                # inicio, catalogo, medio_detalle, nuevo_envio,
│                               # confirmacion, rastreo, chat, estado
└── docs/                       # api.md, arquitectura.md, patrones.md, informes/
```

## 5. Fragmentos clave

### 5.1 Dockerfile de recomendar (`services/recomendar/Dockerfile`)

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Entrena el modelo al construir la imagen, nunca dentro de una petición HTTP.
RUN python -m entrenamiento.entrenar
RUN useradd --create-home app && chown -R app /app
USER app
EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
```

### 5.2 Vista y decisión del recomendador

`services/recomendar/recomendar/views.py`:

```python
@solo("POST")
def recomendar(request):
    """POST /api/recomendar/ con peso_kg, distancia_km, urgente y dimensiones_cm."""
    envio = validar_envio(leer_json(request.body))

    recomendador = modelo.obtener()          # cargado una vez al iniciar el servicio
    if recomendador is None:
        raise modelo_no_disponible(modelo.error_carga())
    try:
        probabilidades = recomendador.probabilidades(envio)
    except Exception:
        logger.exception("Falló la predicción del modelo")
        raise modelo_no_disponible("El modelo no pudo procesar la solicitud")

    return respuesta_json(decidir(envio, probabilidades))
```

`services/recomendar/recomendar/recomendacion.py`, la función `recomendar` (que en la vista se importa como `decidir`):

```python
def recomendar(envio, probabilidades, reglas=REGLAS):
    ordenados = sorted(MEDIOS, key=lambda m: (-probabilidades.get(m, 0.0), MEDIOS.index(m)))
    medio_modelo = ordenados[0]
    aptos, descartes = [], {}
    for medio in ordenados:
        regla, motivo = primera_regla_que_descarta(envio, medio, reglas)
        if regla is None:
            aptos.append(medio)
        else:
            descartes[medio] = (regla, motivo)
    if not aptos:
        raise ErrorApi("sin_medio_apto", "Ningún medio cumple las reglas de negocio: ...", 400)
    medio_final = aptos[0]
    corregido = medio_final != medio_modelo
    ...
    return {
        "medio_modelo": medio_modelo,
        "confianza": round(probabilidades.get(medio_modelo, 0.0), 4),
        "medio_final": medio_final,
        "corregido_por_reglas": corregido,
        "motivo": motivo,
        "alternativas": [{"medio": m, "confianza": ...} for m in aptos[1:]],
    }
```

`services/recomendar/recomendar/modelo.py`: carga `modelos/recomendador.joblib` (o la ruta en `MODELO_RUTA`) con `joblib.load` al iniciar el servicio.

### 5.3 Cliente HTTP de Flutter (`app_flutter/lib/config.dart` y `services/api_client.dart`)

```dart
// config.dart
const String _apiUrlDefinida = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);
```

```dart
// api_client.dart: único lugar de la app que hace HTTP. Tiempo límite: 8 s.
Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() llamada) async {
  final http.Response respuesta;
  try {
    respuesta = await llamada().timeout(tiempoLimite);
  } on TimeoutException {
    throw ApiException('El servidor tardó más de ${tiempoLimite.inSeconds} s en responder.',
        tipo: TipoError.tiempoAgotado);
  } on http.ClientException {
    throw _sinConexion;
  } on Exception {
    throw _sinConexion;
  }
  return _procesar(respuesta);   // 2xx → JSON; otro código → ApiException con "error"/"detalle"
}

// Métodos públicos:
// listarMedios({q})      → GET  /api/catalogo/medios/
// obtenerMedio(clave)    → GET  /api/catalogo/medios/<clave>/
// listarTiposServicio()  → GET  /api/catalogo/tipos-servicio/
// registrarPedido(...)   → POST /api/pedidos/          (con Idempotency-Key)
// consultarPedido(folio) → GET  /api/pedidos/<folio>/
// enviarMensaje(texto)   → POST /api/asistente/
// (estado_screen consulta /api/<servicio>/health/ de los 4 servicios)
```

### 5.4 Gateway (`gateway/nginx.conf`, extracto)

```nginx
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, PATCH, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Type, Idempotency-Key" always;
if ($request_method = OPTIONS) { return 204; }

proxy_connect_timeout 3s;
proxy_send_timeout 10s;
proxy_read_timeout 10s;
error_page 502 503 504 = @servicio_no_disponible;

location /api/catalogo/   { set $destino catalogo:8000;   proxy_pass http://$destino; }
location /api/pedidos/    { set $destino pedidos:8000;    proxy_pass http://$destino; }
location /api/recomendar/ { set $destino recomendar:8000; proxy_pass http://$destino; }
location /api/asistente/  { set $destino asistente:8000;  proxy_pass http://$destino; }

location @servicio_no_disponible {
    return 503 '{"error": "servicio_no_disponible", "detalle": "El servicio $servicio no respondió"}';
}
location / { return 404 '{"error": "ruta_no_encontrada", "detalle": "La ruta solicitada no existe"}'; }
```

### 5.5 Configuración de Django (igual en los 4 servicios)

```python
SECRET_KEY = os.environ.get("SECRET_KEY", "solo-para-desarrollo-cambiar-en-otros-entornos")
DEBUG = _env_bool("DEBUG", False)
ALLOWED_HOSTS = _env_lista("ALLOWED_HOSTS", "localhost,127.0.0.1")
```

---

## Qué NO le pasamos (para el informe)

- El `.env` real ni ninguna contraseña o `SECRET_KEY` real.
- El historial de Git.
- Los datasets completos (`envios.csv`, `intenciones.csv`) ni los `.joblib`.
- Las pruebas (`tests.py`, `app_flutter/test/`) ni el código completo de las pantallas Flutter.
