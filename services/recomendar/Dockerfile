FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Entrena el modelo al construir la imagen con un script aparte, nunca dentro de una petición
# HTTP. El dataset y la semilla son fijos, así que cada build produce el mismo modelo. Si el
# entrenamiento falla, el build falla.
RUN python -m entrenamiento.entrenar

RUN useradd --create-home app && chown -R app /app
USER app

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
