/// Datos de prueba compartidos por las pruebas de pedidos.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Respuesta JSON en UTF-8 como la manda el gateway.
http.Response respuestaJson(Object cuerpo, int codigo) => http.Response.bytes(
  utf8.encode(jsonEncode(cuerpo)),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Respuesta de registro tal como la manda el servidor (dimensiones como 30.0).
Map<String, dynamic> pedidoJson({String folio = 'PQ-20261117-C3JU'}) => {
  'folio': folio,
  'estado': 'CREADO',
  'origen': 'Av. Juárez 100, Centro, Guadalajara',
  'destino': 'Calle Hidalgo 25, Zapopan',
  'distancia_km': 8.5,
  'peso_kg': 2.3,
  'dimensiones_cm': {'largo': 30.0, 'ancho': 20.0, 'alto': 15.0},
  'urgente': false,
  'seguro': true,
  'fecha_limite': '2026-11-20',
  'medio': 'motocicleta',
  'tipo_servicio': 'express',
  'costo': 129.11,
  'moneda': 'MXN',
  'fecha_creacion': '2026-11-17T22:09:12-06:00',
};

/// Respuesta de la consulta por folio.
Map<String, dynamic> resumenJson({String folio = 'PQ-20261117-C3JU', String estado = 'CREADO'}) => {
  'folio': folio,
  'estado': estado,
  'medio': 'motocicleta',
  'tipo_servicio': 'express',
  'fecha_creacion': '2026-11-17T22:09:12-06:00',
  'fecha_limite': '2026-11-20',
  'actualizado_en': '2026-11-17T22:09:14-06:00',
};

Map<String, dynamic> _medio(String clave, String nombre, num pesoMax, num distanciaMax) => {
  'clave': clave,
  'nombre': nombre,
  'descripcion': 'Descripción de $nombre',
  'peso_max_kg': pesoMax,
  'distancia_max_km': distanciaMax,
  'velocidad_kmh': 35.0,
  'costo_base': 40.0,
  'costo_por_km': 4.5,
};

final Map<String, dynamic> mediosJson = {
  'medios': [_medio('motocicleta', 'Motocicleta', 20, 40), _medio('dron', 'Dron', 2, 10)],
  'total': 2,
};

final Map<String, dynamic> tiposJson = {
  'tipos_servicio': [
    {
      'clave': 'estandar',
      'nombre': 'Estándar',
      'descripcion': 'Entrega en hasta 3 días',
      'tiempo_max_horas': 72,
      'multiplicador_costo': 1.0,
    },
    {
      'clave': 'express',
      'nombre': 'Express',
      'descripcion': 'Entrega en hasta 24 horas',
      'tiempo_max_horas': 24,
      'multiplicador_costo': 1.5,
    },
  ],
  'total': 2,
};
