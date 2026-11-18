from django.test import SimpleTestCase, TestCase

CONTENT_TYPE = "application/json; charset=utf-8"


class HealthTests(SimpleTestCase):
    def test_health_responde_200_con_json_acordado(self):
        respuesta = self.client.get("/api/catalogo/health/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(respuesta.json(), {"servicio": "catalogo", "ok": True})


class MediosTests(TestCase):
    fixtures = ["catalogo_inicial.json"]

    def test_listado_devuelve_los_cuatro_medios(self):
        respuesta = self.client.get("/api/catalogo/medios/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        datos = respuesta.json()
        self.assertEqual(datos["total"], 4)
        self.assertEqual(
            [m["clave"] for m in datos["medios"]],
            ["camioneta", "motocicleta", "bicicleta", "dron"],
        )

    def test_listado_tiene_los_campos_del_contrato(self):
        medio = self.client.get("/api/catalogo/medios/").json()["medios"][0]

        self.assertEqual(
            set(medio),
            {
                "clave", "nombre", "descripcion", "peso_max_kg", "distancia_max_km",
                "velocidad_kmh", "costo_base", "costo_por_km",
            },
        )

    def test_busqueda_con_resultado(self):
        respuesta = self.client.get("/api/catalogo/medios/", {"q": "moto"})

        self.assertEqual(respuesta.status_code, 200)
        datos = respuesta.json()
        self.assertEqual(datos["total"], 1)
        self.assertEqual(datos["medios"][0]["clave"], "motocicleta")

    def test_busqueda_ignora_mayusculas_y_acentos(self):
        # "RAPIDAS" debe encontrar "Entregas rápidas en ciudad".
        datos = self.client.get("/api/catalogo/medios/", {"q": "RAPIDAS"}).json()

        self.assertEqual([m["clave"] for m in datos["medios"]], ["motocicleta"])

    def test_busqueda_en_descripcion(self):
        datos = self.client.get("/api/catalogo/medios/", {"q": "ligeros"}).json()

        self.assertEqual([m["clave"] for m in datos["medios"]], ["bicicleta", "dron"])

    def test_busqueda_sin_resultado(self):
        respuesta = self.client.get("/api/catalogo/medios/", {"q": "submarino"})

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json(), {"medios": [], "total": 0})

    def test_q_vacio_devuelve_todos(self):
        datos = self.client.get("/api/catalogo/medios/", {"q": "  "}).json()

        self.assertEqual(datos["total"], 4)

    def test_q_demasiado_largo_responde_400(self):
        respuesta = self.client.get("/api/catalogo/medios/", {"q": "a" * 101})

        self.assertEqual(respuesta.status_code, 400)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(respuesta.json()["error"], "datos_invalidos")
        self.assertIn("detalle", respuesta.json())

    def test_detalle_existente(self):
        respuesta = self.client.get("/api/catalogo/medios/dron/")

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(
            respuesta.json(),
            {
                "clave": "dron",
                "nombre": "Dron",
                "descripcion": "Paquetes ligeros en distancias cortas",
                "peso_max_kg": 2,
                "distancia_max_km": 10,
                "velocidad_kmh": 60,
                "costo_base": 80.0,
                "costo_por_km": 6.0,
            },
        )

    def test_detalle_inexistente_responde_404(self):
        respuesta = self.client.get("/api/catalogo/medios/submarino/")

        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(
            respuesta.json(),
            {"error": "no_encontrado", "detalle": "No existe el medio con clave submarino"},
        )


class TiposServicioTests(TestCase):
    fixtures = ["catalogo_inicial.json"]

    def test_lista_los_tres_tipos(self):
        respuesta = self.client.get("/api/catalogo/tipos-servicio/")

        self.assertEqual(respuesta.status_code, 200)
        datos = respuesta.json()
        self.assertEqual(datos["total"], 3)
        self.assertEqual(
            datos["tipos_servicio"][2],
            {
                "clave": "mismo_dia",
                "nombre": "Mismo día",
                "descripcion": "Entrega el mismo día",
                "tiempo_max_horas": 12,
                "multiplicador_costo": 2.0,
            },
        )


class ErroresGeneralesTests(TestCase):
    def test_ruta_inexistente_responde_404_en_json(self):
        respuesta = self.client.get("/api/catalogo/no-existe/")

        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta["Content-Type"], CONTENT_TYPE)
        self.assertEqual(respuesta.json()["error"], "ruta_no_encontrada")

    def test_metodo_no_soportado_responde_404(self):
        respuesta = self.client.post("/api/catalogo/medios/")

        self.assertEqual(respuesta.status_code, 404)
        self.assertEqual(respuesta.json()["error"], "ruta_no_encontrada")
