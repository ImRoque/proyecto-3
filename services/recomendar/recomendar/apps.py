from django.apps import AppConfig


class RecomendarConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "recomendar"

    def ready(self):
        # Se carga el modelo una sola vez al iniciar el proceso (cada worker de gunicorn).
        from . import modelo

        modelo.cargar()
