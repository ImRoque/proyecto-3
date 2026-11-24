from django.apps import AppConfig


class AsistenteConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "asistente"

    def ready(self):
        # Se carga el modelo una sola vez al iniciar el proceso (cada worker de gunicorn).
        from . import modelo

        modelo.cargar()
