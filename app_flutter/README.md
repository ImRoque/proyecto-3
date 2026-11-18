# app_flutter

**Propósito:** aplicación Flutter única que se ejecuta en navegador y en Android con el mismo código.

**Responsable:** Int. 5

## Estado actual (Etapa 4, Hito A)

Solo hay una **pantalla de estado** que consulta `GET /api/<servicio>/health/` de los 4 servicios
a través del gateway y muestra cada uno como *Conectado* o *No disponible*, con botón
*Reintentar*. Sirve para comprobar que web y Android llegan al gateway.

## Estructura de `lib/`

| Archivo | Responsabilidad |
|---|---|
| `config.dart` | URL base del gateway, leída con `String.fromEnvironment('API_URL')`. Por defecto `http://localhost:8080`. |
| `services/api_client.dart` | `ApiClient`: **único** lugar que hace llamadas HTTP. Tiempo límite de 5 s y conversión de errores de red, tiempo agotado y `503` en `ApiException` con un mensaje claro. |
| `screens/estado_screen.dart` | Pantalla de estado de los servicios. |
| `main.dart` | Abre la pantalla de estado. |

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
