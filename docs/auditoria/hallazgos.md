# Hallazgos de la auditoría con IA — verificados en el código

- **IA A:** `qwen2.5-coder:7b` (local, Ollama, CPU sin GPU)
- **IA B:** `llama3.2` 3B (local, Ollama, CPU sin GPU)
- **Entrada:** [contexto-ia.md](contexto-ia.md) (mismo paquete para las dos)

## Tabla de hallazgos

| # | Hallazgo | IA A | IA B | ¿Lo vimos en el código? | Evidencia | Qué haremos |
|---|---|---|---|---|---|---|
| 1 | Si falta el `.joblib`, el servicio falla al iniciar | sí (alta) | no | **no — falso positivo** | `services/recomendar/recomendar/modelo.py`, `cargar()`: captura `FileNotFoundError` y cualquier otra excepción; el servicio arranca y la ruta responde `503 modelo_no_disponible`. Pruebas: `test_archivo_inexistente_deja_el_servicio_en_503`, `test_archivo_danado_deja_el_servicio_en_503` en `recomendar/tests.py`. | Nada |
| 2 | `recomendar()` no compara el medio final con el del modelo | sí (media) | no | **no — falso positivo** | `recomendacion.py`: `corregido = medio_final != medio_modelo` y la respuesta devuelve `corregido_por_reglas` y `motivo`. Pruebas: `test_regla_de_peso_corrige_al_modelo`, `test_regla_de_tamano_corrige_al_modelo`. | Nada |
| 3 | El tiempo límite de Flutter (8 s) es menor que el del gateway (10 s) | sí (media) | no | **parcial — es una decisión de diseño, no un error** | `api_client.dart`, comentario de `tiempoLimitePorDefecto`: 8 s está por encima del peor caso de pedidos (2 × 3 s hacia catálogo) y por debajo de los 10 s del gateway, a propósito. Si el servidor tarda más de 8 s, la app muestra `tiempoAgotado`, que es lo esperado. | Nada |
| 4 | CORS abierto (`Access-Control-Allow-Origin: *`) | sí (baja) | no | **sí** (pero "permite todas las solicitudes" es falso) | `gateway/nginx.conf`: `Allow-Origin "*"`, aunque los métodos se limitan a `GET, POST, PATCH, OPTIONS` y los encabezados a `Content-Type, Idempotency-Key`. Para desarrollo y demo local es aceptable. | **Hecho:** anotado como pendiente en `README.md` |
| 5 | `register_order` no valida la `Idempotency-Key`; puede duplicar pedidos | sí (alta) | no | **no — falso positivo (inventó el nombre de la función)** | La función se llama `registrar` (`pedidos/views.py`). La clave se valida en `validacion.py`, `validar_idempotency_key()` (obligatoria, UUID v4), se revisa en `confirmacion.py` y `models.py` tiene `idempotency_key = models.UUIDField(unique=True)`. Pruebas: `test_misma_clave_y_mismo_cuerpo_devuelve_el_mismo_folio`, `test_carrera_la_restriccion_unica_evita_el_duplicado`, `test_sin_idempotency_key_responde_400`. | Nada |
| 6 | El `.joblib` está en `services/recomendar/.gitignore` y puede faltar en la imagen | sí | no | **no — inventó un archivo** | No existe `services/recomendar/.gitignore`. `modelos/` aparece en `.dockerignore`, pero el modelo se genera *dentro* de la imagen con `RUN python -m entrenamiento.entrenar`, después del `COPY`. | Nada |
| 7 | Entrenar al construir la imagen es un riesgo de seguridad y rendimiento | no | sí (alta) | **no — es lo que pide el enunciado** | El enunciado exige el modelo en el servidor y no entrenar por petición. La IA B no dio ningún riesgo concreto y citó una ruta que no existe (`services/recomendar/recomendar/Dockerfile`; el real es `services/recomendar/Dockerfile`). | Nada |
| 8 | Revisar autenticación y autorización | no | sí (comprobación) | **no aplica** | El proyecto no tiene usuarios ni login. La IA B lo sugirió sin evidencia en el paquete. | Nada (confirmar con el enunciado) |
| 9 | Falta documentación de las pantallas Flutter | no | sí (hipótesis) | **parcial** | `app_flutter/README.md` describe los servicios y las URLs, pero no tiene una sección por pantalla. Además, no le pasamos ese README a la IA. | Opcional |

### Hallazgos de la revisión manual (ninguna IA los mencionó)

| # | Hallazgo | Evidencia | Qué haremos |
|---|---|---|---|
| M1 | El README raíz marca todo como "(pendiente)" | `README.md`, tabla "Estructura" | **Hecho:** tabla actualizada |
| M2 | No está documentado el build web ni el build apk | No aparece `flutter build` en ningún README ni en `docs/` | **Hecho:** sección "Compilar web y apk" en `app_flutter/README.md` y resumen en `README.md` |
| M3 | Un apk compilado sin `--dart-define` apunta a `localhost:8080` | `app_flutter/lib/config.dart`, `defaultValue` | **Hecho:** advertencia en la misma sección; el apk se compila en `--debug` porque release no permite `http://` |
| M4 | `docs/patrones.md` incompleto (Gateway/BFF, Observer, Front Controller, MVC, web vs móvil) | `docs/patrones.md` | Completarlo el equipo |

## Falsos positivos para el informe (mínimo 2)

1. **Qwen dijo** que si falta el `.joblib` el servicio "fallará inmediatamente". **En `modelo.py`** se ve que `cargar()` captura `FileNotFoundError` y la ruta responde `503 modelo_no_disponible`; hay una prueba para eso.
2. **Qwen dijo** que `register_order` no valida la `Idempotency-Key`. **Esa función no existe**: es `registrar`, y la clave se valida en `validacion.py` y está protegida por `unique=True` en `models.py`.
3. **Qwen citó** `services/recomendar/.gitignore`, que **no existe**, aunque el prompt le pedía no inventar archivos.

## Conclusión

- La IA A (qwen, especializada en código) dio hallazgos concretos, pero de 6 solo 1 resultó cierto (CORS) y 1 parcial (tiempos límite). Inventó un nombre de función y un archivo.
- La IA B (llama3.2 3B) dio recomendaciones genéricas, sin hallazgos comprobables, y citó una ruta equivocada.
- Ninguna de las dos detectó los problemas reales de documentación (M1 a M4), porque el paquete no incluía los README. La revisión humana fue indispensable.
