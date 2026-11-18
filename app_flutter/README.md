# app_flutter

**Propósito:** aplicación Flutter única que se ejecuta en navegador y en Android con el mismo código.

**Responsable:** Int. 5

## Estado actual (Etapa 5, Hito B)

La app abre con una **navegación inferior** de cuatro pestañas:

- **Catálogo:** lista los medios de entrega de `GET /api/catalogo/medios/` con un campo de
  búsqueda (`?q=`, máximo 100 caracteres) que consulta al escribir, después de 400 ms sin
  teclear, o al pulsar Enter. Muestra estados de **cargando**, **error con Reintentar** y
  **sin resultados**. Al tocar un medio abre su detalle (`GET /api/catalogo/medios/<clave>/`).
- **Enviar:** formulario de pedido (`POST /api/pedidos/`). El medio y el tipo de servicio se
  eligen de listas del catálogo; todavía no hay recomendación. Valida los campos antes de
  enviar (obligatorios, números mayores que 0, fecha no anterior a hoy y capacidad del medio),
  pero la decisión final es del servidor. Al confirmar muestra el **folio**.
- **Rastrear:** consulta por folio (`GET /api/pedidos/<folio>/`) con la **línea de estados**
  `CREADO → EN_CAMINO → ENTREGADO` (o `CREADO → CANCELADO`) y estados de **cargando**,
  **error con Reintentar** y **folio no encontrado**.
- **Estado:** la pantalla de la Etapa 4, que consulta `GET /api/<servicio>/health/` de los
  4 servicios y muestra cada uno como *Conectado* o *No disponible*.

## Estructura de `lib/`

| Archivo | Responsabilidad |
|---|---|
| `config.dart` | URL base del gateway, leída con `String.fromEnvironment('API_URL')`. Por defecto `http://localhost:8080`. |
| `services/api_client.dart` | `ApiClient`: **único** lugar que hace llamadas HTTP. Tiempo límite de 5 s y conversión de errores de red, tiempo agotado y `503` en `ApiException` con un mensaje claro. Métodos del catálogo: `listarMedios({q})`, `obtenerMedio(clave)` y `listarTiposServicio()`. Pedidos: `registrarPedido(solicitud, idempotencyKey:)` y `consultarPedido(folio)`. |
| `models/medio_entrega.dart` | `MedioEntrega` con `fromJson` según el contrato de `docs/api.md`. |
| `models/tipo_servicio.dart` | `TipoServicio` del catálogo. |
| `models/pedido.dart` | `SolicitudPedido` (cuerpo del registro), `Pedido` (respuesta completa), `PedidoResumen` (consulta por folio), estados y formato del folio. |
| `services/idempotencia.dart` | Genera el UUID v4 de `Idempotency-Key` con `Random.secure()`. |
| `screens/inicio_screen.dart` | Navegación inferior (Catálogo y Estado). |
| `screens/catalogo_screen.dart` | Catálogo con búsqueda. |
| `screens/medio_detalle_screen.dart` | Detalle de un medio de entrega. |
| `screens/estado_screen.dart` | Pantalla de estado de los servicios. |
| `screens/nuevo_envio_screen.dart` | Formulario de nuevo envío. |
| `screens/confirmacion_screen.dart` | Envío registrado: folio, costo y accesos a rastrear o a un envío nuevo. |
| `screens/rastreo_screen.dart` | Consulta por folio y `LineaEstados`. |
| `main.dart` | Abre la pantalla de inicio. |

Las pantallas no hacen HTTP directo: todo pasa por `ApiClient`.
Las pantallas nunca escriben la URL del API: la reciben de `config.dart`.

## URL base por plataforma

| Plataforma | `API_URL` |
|---|---|
| Web (Chrome) | `http://localhost:8080` |
| Emulador Android | `http://10.0.2.2:8080` |
| Teléfono físico en la misma red | `http://<IP-de-la-PC>:8080` |

## Cómo ejecutar

Primero levanta el backend desde la raíz del repositorio (ver [README principal](../README.md)):

```bash
docker compose up -d --build
```

Después, dentro de `app_flutter/`:

```bash
flutter pub get
```

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

```bash
flutter emulators --launch <id-del-emulador>
flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8080
```

(`flutter devices` muestra el id real del emulador o teléfono.)

## Android

- `INTERNET` está declarado en `android/app/src/main/AndroidManifest.xml`.
- HTTP sin cifrar (`usesCleartextTraffic`) se permite **solo en debug y profile**
  (`android/app/src/debug/` y `profile/`). Un APK release no puede llamar a `http://`.

## Pruebas

```bash
flutter analyze
flutter test
```

Las pruebas usan `MockClient` del paquete `http`; no necesitan el backend.

### Doble toque al confirmar un envío

Dos toques rápidos en **Confirmar envío** nunca crean dos pedidos:

1. El botón se deshabilita mientras espera la respuesta, y el método ignora un segundo toque
   que llegue en el mismo cuadro, antes de que el botón se redibuje.
2. Cada formulario tiene una `Idempotency-Key` que se genera al abrirlo, se reutiliza en todos
   los reintentos (por ejemplo, tras un error de red) y solo se renueva cuando el pedido se
   registró con éxito. Si el servidor ya lo había registrado, responde con el mismo folio.

Si después de un error el usuario cambia datos y el servidor responde
`409 idempotency_key_reutilizada`, la pantalla ofrece **Empezar envío nuevo**, que genera otra
clave a propósito.

Nota: **`pubspec.lock` se versiona** (es una aplicación, no una librería).
