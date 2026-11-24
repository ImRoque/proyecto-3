# services/recomendar

**Propósito:** microservicio del recomendador (IA 1): modelo entrenado y reglas de negocio adaptados al tema.


## Contenido previsto (pendiente de acuerdo)

- Dataset y script de entrenamiento (fuera de la petición HTTP)
- Artefacto del modelo y métrica
- Reglas que pueden corregir al modelo
- Endpoint de recomendación
- Pruebas


## Estado actual

Esqueleto Django 5 (proyecto `config`, app `recomendar`). Por ahora solo expone la ruta
de salud definida en `docs/api.md`:

```
GET /api/recomendar/health/  ->  200  {"servicio": "recomendar", "ok": true}
```

## Modelo del recomendador (IA 1)

El modelo se entrena **fuera de la API**, con scripts aparte. Las vistas todavía no lo usan.

| Archivo | Qué es |
|---|---|
| `entrenamiento/generar_dataset.py` | Genera `datasets/envios.csv` de forma reproducible. |
| `datasets/envios.csv` | Dataset sintético de 3000 envíos. |
| `entrenamiento/entrenar.py` | Entrena el clasificador, imprime métricas y guarda el modelo. |
| `modelos/recomendador.joblib` | Modelo entrenado (ver "Archivo del modelo"). |
| `entrenamiento/tests.py` | Pruebas del generador y del entrenamiento. |

### Features y etiqueta

| Columna | Tipo | Descripción |
|---|---|---|
| `peso_kg` | número | Peso del paquete. |
| `distancia_km` | número | Distancia del envío. |
| `urgente` | 0 o 1 | 1 si el envío es urgente. |
| `largo_cm`, `ancho_cm`, `alto_cm` | número | Dimensiones del paquete. |
| `medio` | texto | **Etiqueta:** `camioneta`, `motocicleta`, `bicicleta` o `dron`. |

Las seis primeras son las features, en ese orden. Son los mismos datos que recibe
`POST /api/recomendar/` (`dimensiones_cm` se separa en tres columnas).

### Cómo se generó el dataset

El dataset es **sintético**: no hay datos reales de envíos. `generar_dataset.py` usa la
semilla fija `42` y solo la biblioteca estándar de Python, así que siempre produce el mismo
archivo.

1. **Muestreo de envíos.** El peso y la distancia salen de rangos que van un poco más allá de
   los límites de cada medio, para que el modelo vea las fronteras. Los pesos y distancias
   grandes usan escala logarítmica. El 30 % de los envíos son urgentes. Las dimensiones
   crecen con la raíz cúbica del peso, con variación de forma.
2. **Medios aptos.** Se descartan los medios que no pueden hacer el envío según las reglas
   R1 a R4 de `docs/api.md` (peso máximo, distancia máxima, lado más largo y urgencia).
   Los límites son los del catálogo.
3. **Etiqueta.** Entre los aptos se elige, en este orden:
   - dron, si el envío es urgente o va a más de ~3 km;
   - bicicleta, la opción más barata para envíos cortos;
   - motocicleta;
   - camioneta en cualquier otro caso.
4. **Ruido.** El umbral de ~3 km del dron varía un poco en cada fila (desviación de 0.5 km),
   y el 5 % de las etiquetas se cambia por **otro medio que también es apto**. Así el dataset
   no es una copia exacta de las reglas, pero nunca tiene una etiqueta imposible (por
   ejemplo, un dron con 50 kg).

Reparto de clases que salió: camioneta 1203, motocicleta 1173, bicicleta 341, dron 283.
Bicicleta y dron son minoría porque solo aplican a envíos ligeros y cortos.

### Cómo entrenar

Desde `services/recomendar/`, con las dependencias instaladas:

```bash
python -m entrenamiento.generar_dataset
```

```bash
python -m entrenamiento.entrenar
```

`entrenar.py` separa 80 % para entrenamiento y 20 % para prueba (estratificado, semilla 42),
entrena un `RandomForestClassifier` (200 árboles, `min_samples_leaf=2`) e imprime accuracy,
matriz de confusión y reporte por clase.

El `.joblib` guarda un diccionario con `modelo`, `features` (orden de las columnas),
`clases`, `sklearn_version` y `accuracy_prueba`. Para cargarlo hace falta la misma versión
de scikit-learn que está en `requirements.txt`.

### Métrica

Resultado real de `python -m entrenamiento.entrenar` con el dataset de este repositorio
(Python 3.12.10, scikit-learn 1.9.1), sobre 600 filas de prueba:

**Accuracy: 0.9617**

Matriz de confusión (filas = real, columnas = predicho):

| | camioneta | motocicleta | bicicleta | dron |
|---|---|---|---|---|
| **camioneta** | 228 | 12 | 0 | 1 |
| **motocicleta** | 1 | 230 | 2 | 1 |
| **bicicleta** | 0 | 3 | 65 | 0 |
| **dron** | 0 | 1 | 2 | 54 |

| Clase | Precisión | Recall | F1 |
|---|---|---|---|
| camioneta | 0.996 | 0.946 | 0.970 |
| motocicleta | 0.935 | 0.983 | 0.958 |
| bicicleta | 0.942 | 0.956 | 0.949 |
| dron | 0.964 | 0.947 | 0.956 |

El error más común es confundir camioneta con motocicleta (12 casos). Parte de los errores
viene del 5 % de ruido que se metió a propósito en las etiquetas. Como el dataset es
sintético, esta métrica mide qué tan bien el modelo aprende las reglas de generación, no su
desempeño con envíos reales. Las reglas de negocio se aplicarán después sobre la salida del
modelo.

### Archivo del modelo

`modelos/recomendador.joblib` pesa cerca de 1.2 MB (comprimido). **Todavía no se sube al
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

Desde `services/recomendar/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver 8000
```

```bash
curl -i http://localhost:8000/api/recomendar/health/
```

## Correrlo con Docker

Desde `services/recomendar/`:

```bash
docker build -t proyecto3-recomendar .
docker run --rm -p 8000:8000 proyecto3-recomendar
```

```bash
curl -i http://localhost:8000/api/recomendar/health/
```

Dentro de Docker Compose, agrega el nombre del servicio a los hosts permitidos, por ejemplo
`ALLOWED_HOSTS=recomendar,localhost`.

## Pruebas

Desde `services/recomendar/`, con las dependencias instaladas:

```bash
python manage.py test
```

Esto incluye las pruebas de `entrenamiento/tests.py`, que entrenan un modelo pequeño en una
carpeta temporal y no tocan `modelos/recomendador.joblib`.
