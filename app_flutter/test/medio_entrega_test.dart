import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto3/models/medio_entrega.dart';

/// Ejemplo de detalle de docs/api.md (enteros y decimales mezclados).
const Map<String, dynamic> dronContrato = {
  'clave': 'dron',
  'nombre': 'Dron',
  'descripcion': 'Paquetes ligeros en distancias cortas',
  'peso_max_kg': 2,
  'distancia_max_km': 10,
  'velocidad_kmh': 60,
  'costo_base': 80.0,
  'costo_por_km': 6.0,
};

void main() {
  test('fromJson lee todos los campos del contrato', () {
    final medio = MedioEntrega.fromJson(dronContrato);

    expect(medio.clave, 'dron');
    expect(medio.nombre, 'Dron');
    expect(medio.descripcion, 'Paquetes ligeros en distancias cortas');
    expect(medio.pesoMaxKg, 2.0);
    expect(medio.distanciaMaxKm, 10.0);
    expect(medio.velocidadKmh, 60.0);
    expect(medio.costoBase, 80.0);
    expect(medio.costoPorKm, 6.0);
  });

  test('fromJson acepta numeros como entero o decimal', () {
    final medio = MedioEntrega.fromJson({...dronContrato, 'peso_max_kg': 2.0, 'costo_base': 80});

    expect(medio.pesoMaxKg, 2.0);
    expect(medio.costoBase, 80.0);
  });

  test('fromJson lanza FormatException si falta un campo', () {
    final incompleto = Map<String, dynamic>.of(dronContrato)..remove('costo_por_km');

    expect(() => MedioEntrega.fromJson(incompleto), throwsFormatException);
  });
}
