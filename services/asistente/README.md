# services/asistente

**Propósito:** microservicio del asistente para el comprador (IA 2), entrenado con datos propios.


## Contenido previsto (pendiente de acuerdo)

- Dataset de intenciones o pares pregunta-respuesta
- Script de entrenamiento, artefacto y métrica
- Endpoint de conversación
- Integración con otros servicios sin romper el borde de entrada
- Pruebas

## Estado actual

Django 5 (proyecto `config`, app `asistente`). Expone las rutas de `docs/api.md`:

```
GET  /api/asistente/health/  ->  200  {"servicio": "asistente", "ok": true}
POST /api/asistente/         ->  200  {"intencion": "...", "respuesta": "..."}
```

## Chat

| Archivo | Qué hace |
|---|---|
| `asistente/modelo.py` | Carga `modelos/intenciones.joblib` **una vez** al iniciar (`AsistenteConfig.ready`). Las peticiones usan el modelo ya cargado. |
| `asistente/extraccion.py` | Saca del mensaje: folio, peso (kg, kilos, gramos), distancia (km, kilómetros, metros), medidas (`30x20x15 cm`) y urgencia. |
| `asistente/clientes.py` | `ClientePedidos` y `ClienteRecomendar`: HTTP interno con tiempo límite total de 3 s. |
| `asistente/adaptador.py` | `AdaptadorChat` (Adapter): convierte el JSON de pedidos y recomendar en texto. |
| `asistente/textos.py` | Respuestas fijas: saludo, horarios, tarifas de referencia, ayuda y mensajes de error. |
| `asistente/conversacion.py` | `Asistente`: detecta la intención y arma la respuesta. |
| `asistente/views.py` | `POST /api/asistente/`: valida el mensaje y devuelve la respuesta. |

### Respuesta por intención

| Intención | Qué hace |
|---|---|
| `rastrear` | Si hay folio, consulta `GET /api/pedidos/<folio>/` y describe estado, medio, servicio y fecha límite. Si no hay folio, lo pide. Si el folio no existe, lo dice. |
| `recomendar` | Necesita peso y distancia; si falta alguno, lo pide. Consulta `POST /api/recomendar/` y responde con `medio_final`, el `motivo` tal como lo da recomendar y las alternativas. Si no vienen medidas, supone 20×15×10 cm y lo avisa. |
| `cotizar` | Texto fijo con las tarifas de referencia del catálogo inicial y el aviso de que el costo exacto se calcula al registrar el pedido (`docs/api.md`). |
| `horarios`, `saludo` | Texto fijo. |
| `desconocida` | Mensaje de ayuda con lo que el asistente sí puede hacer. |

Cómo se elige la intención:

1. Si el mensaje trae un folio válido (`PQ-AAAAMMDD-XXXX`), es `rastrear`. Así funciona
   contestar solo el folio después de que el asistente lo pidió.
2. Si no, la decide el clasificador. Si su confianza es menor que **0.40**, es `desconocida`.

**Por qué 0.40.** Lo medí con el modelo real sobre los 38 mensajes de prueba y 11 mensajes
fuera de tema:

- Pasan a `desconocida` 7 de los 11 fuera de tema ("¿Venden pizzas?", "asdfgh", "gracias",
  etc.) y 2 de los 4 errores de prueba.
- A cambio, 2 de los 38 mensajes de prueba bien clasificados también caen en `desconocida`
  (confianza 0.34 y 0.36).
- Quedan mal 4 fuera de tema con confianza alta: "¿Qué hora es?" sale como `horarios`
  (0.85) y "recomiéndame una película" como `recomendar` (0.80). Esto solo se arregla con
  más datos.

### Servicios caídos

Si pedidos o recomendar no responden en **3 segundos**, responden 5xx (incluido
`503 modelo_no_disponible`) o mandan algo que no es JSON, el chat **no falla**: responde
`200` con la intención y un mensaje amable ("En este momento no puedo consultar tu
pedido..."). Saludo, horarios y cotizar siguen funcionando porque no llaman a nadie.

El tiempo límite cubre toda la llamada, incluida la búsqueda DNS. Con un contenedor apagado,
resolver su nombre tarda unos 4 s y el `timeout` de `urlopen` no lo corta; por eso cada
llamada corre en un hilo y se espera como máximo 3 s.

| Caso | Respuesta |
|---|---|
| Falta `mensaje`, viene vacío o solo con espacios | `400 mensaje_vacio` |
| No es JSON, `mensaje` no es texto o pasa de 500 caracteres | `400 datos_invalidos` |
| No hay modelo cargado | `503 modelo_no_disponible` |

### Evidencia por el gateway

Ejecutado el 2026-11-23 con `docker compose up -d --build`, llamando a
`http://localhost:8080`. Primero se registró un pedido real (`POST /api/pedidos/`), que
devolvió el folio `PQ-20261123-Y8A6`, y se pasó a `EN_CAMINO`
(`PATCH /api/pedidos/PQ-20261123-Y8A6/estado/`).

> En Git Bash de Windows, curl no manda en UTF-8 los acentos escritos en la línea de
> comandos y el asistente responde `400 datos_invalidos`. Para probar, guarda el cuerpo en
> un archivo UTF-8 y usa `--data-binary @archivo.json`.

```bash
curl -s -X POST http://localhost:8080/api/asistente/ -H "Content-Type: application/json; charset=utf-8" --data-binary @mensaje.json
```

**"¿cómo va el folio PQ-20261123-Y8A6?"**

```json
{"intencion": "rastrear", "respuesta": "Tu pedido PQ-20261123-Y8A6 va en camino (EN_CAMINO). Va en motocicleta, servicio express. Fecha límite: 2026-11-26."}
```

**"¿qué me recomiendas para 3 kg a 5 km?"**

```json
{"intencion": "recomendar", "respuesta": "Te recomiendo enviarlo en bicicleta. El modelo propuso bicicleta y cumple todas las reglas de negocio. Otras opciones: motocicleta, camioneta. Supuse una caja chica de 20×15×10 cm; si es más grande, dime las medidas (por ejemplo 40x30x20 cm)."}
```

El asistente mandó a recomendar `{"peso_kg": 3.0, "distancia_km": 5.0, "urgente": false,
"dimensiones_cm": {"largo": 20, "ancho": 15, "alto": 10}}`. Recomendar respondió
`medio_final: "bicicleta"` con ese mismo `motivo`.

**"¿qué horarios tienen?"**

```json
{"intencion": "horarios", "respuesta": "Atendemos de lunes a sábado de 8:00 a 20:00. Las entregas salen de lunes a sábado de 9:00 a 19:00; los domingos y días festivos no hay entregas. El servicio mismo día se puede pedir hasta las 14:00."}
```

**Con pedidos apagado** (`docker compose stop pedidos`), la misma pregunta del folio
respondió `200` en 3.0 s:

```json
{"intencion": "rastrear", "respuesta": "En este momento no puedo consultar tu pedido. Intenta de nuevo en unos minutos."}
```

Al volver a encender pedidos (`docker compose start pedidos`), la consulta del folio
respondió otra vez con el estado del pedido.

## Clasificador de intenciones (IA 2)

El clasificador se entrena **fuera de la API**, con un script aparte. El servicio solo lo
carga al iniciar.

| Archivo | Qué es |
|---|---|
| `datasets/intenciones.csv` | Mensajes de ejemplo con su intención (columnas `texto`, `intencion`). |
| `entrenamiento/entrenar.py` | Entrena el clasificador, imprime métricas y guarda el modelo. |
| `modelos/intenciones.joblib` | Modelo entrenado (ver "Archivo del modelo"). |
| `entrenamiento/tests.py` | Pruebas del dataset y del entrenamiento. |

### Intenciones

Son las cinco de `docs/api.md` que se entrenan:

| Intención | Para qué | Ejemplo del dataset |
|---|---|---|
| `saludo` | Saludar o abrir la conversación | "Qué onda" |
| `horarios` | Horarios de atención y entrega | "¿Abren los domingos?" |
| `cotizar` | Precios y tarifas | "¿Cuánto me sale mandar 10 kg a 20 km?" |
| `rastrear` | Estado de un pedido, con o sin folio | "checa mi folio PQ-20261116-T6YU porfa" |
| `recomendar` | Qué medio conviene para un envío | "¿Lo mando en bici o en moto?" |

La intención `desconocida` **no se entrena**. Según `docs/api.md`, se usa cuando la
confianza del clasificador es baja; el umbral se definirá al conectar el modelo con la vista.

### Dataset

- **150 mensajes, 30 por intención.** Están escritos a mano como escribiría un cliente en
  México: con y sin acentos, con abreviaturas ("q tal", "porfa"), con folios en mayúsculas y
  minúsculas, y con datos del paquete ("3 kg a 6 km, 30x20x15 cm").
- No hay mensajes repetidos; una prueba lo revisa.
- Las parejas que más se parecen son `cotizar` y `recomendar` (las dos hablan de peso y
  distancia) y `horarios` y `recomendar` (las dos hablan de mandar paquetes).

### Cómo entrenar

Desde `services/asistente/`, con las dependencias instaladas:

```bash
python -m entrenamiento.entrenar
```

El script:

1. Lee `datasets/intenciones.csv` y revisa las columnas, que las intenciones sean válidas y
   que haya al menos 20 ejemplos de cada una.
2. Separa 75 % para entrenamiento y 25 % para prueba, **estratificado** por intención
   (semilla 42).
3. Entrena un `Pipeline` de scikit-learn:
   - `TfidfVectorizer` con n-gramas de 2 a 5 caracteres (`char_wb`), en minúsculas y sin
     acentos, para tolerar faltas de ortografía;
   - `LogisticRegression` (`C=10`).
4. Imprime accuracy, reporte por intención, matriz de confusión y los mensajes de prueba que
   falló.
5. Como la prueba tiene solo 38 mensajes, también calcula una validación cruzada de 5
   pliegues sobre el conjunto de entrenamiento.
6. Guarda `modelos/intenciones.joblib`: un diccionario con `modelo` (el pipeline completo,
   recibe texto), `intenciones`, `sklearn_version` y `accuracy_prueba`.

Para cargarlo hace falta la misma versión de scikit-learn que está en `requirements.txt`.

### Métrica

Resultado real de `python -m entrenamiento.entrenar` (Python 3.12.10, scikit-learn 1.9.1):

- **Accuracy en prueba: 0.8947** (34 de 38 mensajes).
- **Validación cruzada:** promedio 0.9016; por pliegue 0.9130, 0.9130, 0.9545, 0.7727 y
  0.9545.

| Intención | Precisión | Recall | F1 | Mensajes de prueba |
|---|---|---|---|---|
| rastrear | 1.000 | 0.875 | 0.933 | 8 |
| cotizar | 0.875 | 0.875 | 0.875 | 8 |
| recomendar | 0.800 | 1.000 | 0.889 | 8 |
| horarios | 0.857 | 0.857 | 0.857 | 7 |
| saludo | 1.000 | 0.857 | 0.923 | 7 |

Errores en prueba:

| Mensaje | Real | Predicha |
|---|---|---|
| "¿Desde qué hora puedo mandar un paquete?" | horarios | recomendar |
| "Qué onda" | saludo | recomendar |
| "¿Tienen promociones o descuentos?" | cotizar | horarios |
| "seguimiento de envío" | rastrear | cotizar |

Lectura de la métrica:

- Con 150 mensajes, cada error en prueba mueve la accuracy unos 2.6 puntos. Por eso los
  pliegues de la validación cruzada van de 0.77 a 0.95.
- Los errores son mensajes que no comparten palabras clave con su intención en el
  entrenamiento ("promociones", "seguimiento") o frases que comparten palabras con otra
  intención ("mandar un paquete" en una pregunta de horario).
- Agregar más ejemplos variados de cada intención es la forma más directa de mejorar.

### Archivo del modelo

`modelos/intenciones.joblib` pesa cerca de 55 KB (comprimido). **Todavía no se sube al
repositorio**: el equipo debe decidir si se versiona o si cada quien lo genera con
`python -m entrenamiento.entrenar` antes de construir la imagen de Docker.

## Variables de entorno

| Variable | Uso | Por defecto |
|---|---|---|
| `SECRET_KEY` | Clave de Django | Valor de desarrollo (cámbiala fuera de tu equipo) |
| `DEBUG` | `True` o `False` | `False` |
| `ALLOWED_HOSTS` | Hosts permitidos, separados por coma | `localhost,127.0.0.1` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` | PostgreSQL | Si no hay `DB_NAME`, usa SQLite |
| `PEDIDOS_URL` | URL interna de pedidos | `http://pedidos:8000` |
| `RECOMENDAR_URL` | URL interna de recomendar | `http://recomendar:8000` |
| `SERVICIOS_TIMEOUT` | Tiempo límite total, en segundos, de cada llamada a otro servicio | `3` |
| `MODELO_RUTA` | Ruta del archivo `.joblib` del clasificador | `modelos/intenciones.joblib` |

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

Esto incluye las pruebas de `entrenamiento/tests.py`, que entrenan en una carpeta temporal y
no tocan `modelos/intenciones.joblib`.
