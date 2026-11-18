from django.test import SimpleTestCase


class HealthTests(SimpleTestCase):
    def test_health_responde_200_con_json_acordado(self):
        respuesta = self.client.get("/api/catalogo/health/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(respuesta.json(), {"servicio": "catalogo", "ok": True})
