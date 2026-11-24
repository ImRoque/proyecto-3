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

## Clasificador de intenciones (IA 2)

El clasificador se entrena **fuera de la API**, con un script aparte. Las vistas todavía no
lo usan.

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
