# app_flutter

**Propósito:** aplicación Flutter única que se ejecuta en navegador y en Android con el mismo código.

**Responsable:** Int. 5

## Estado actual (Etapa 5, Hito B)

La app abre con una **navegación inferior** de dos pestañas:

- **Catálogo:** lista los medios de entrega de `GET /api/catalogo/medios/` con un campo de
  búsqueda (`?q=`, máximo 100 caracteres) que consulta al escribir, después de 400 ms sin
  teclear, o al pulsar Enter. Muestra estados de **cargando**, **error con Reintentar** y
  **sin resultados**. Al tocar un medio abre su detalle (`GET /api/catalogo/medios/<clave>/`).
- **Estado:** la pantalla de la Etapa 4, que consulta `GET /api/<servicio>/health/` de los
  4 servicios y muestra cada uno como *Conectado* o *No disponible*.

## Estructura de `lib/`

| Archivo | Responsabilidad |
|---|---|
| `config.dart` | URL base del gateway, leída con `String.fromEnvironment('API_URL')`. Por defecto `http://localhost:8080`. |
| `services/api_client.dart` | `ApiClient`: **único** lugar que hace llamadas HTTP. Tiempo límite de 5 s y conversión de errores de red, tiempo agotado y `503` en `ApiException` con un mensaje claro. Métodos del catálogo: `listarMedios({q})` y `obtenerMedio(clave)`. |
| `models/medio_entrega.dart` | `MedioEntrega` con `fromJson` según el contrato de `docs/api.md`. |
| `screens/inicio_screen.dart` | Navegación inferior (Catálogo y Estado). |
| `screens/catalogo_screen.dart` | Catálogo con búsqueda. |
| `screens/medio_detalle_screen.dart` | Detalle de un medio de entrega. |
| `screens/estado_screen.dart` | Pantalla de estado de los servicios. |
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

Nota: **`pubspec.lock` se versiona** (es una aplicación, no una librería).
