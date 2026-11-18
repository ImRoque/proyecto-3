import 'dart:math';

final Random _aleatorio = Random.secure();

/// Genera un UUID v4 (RFC 9562) para el encabezado `Idempotency-Key`.
///
/// Se usa un generador criptográfico para que dos dispositivos no produzcan la misma clave.
String generarUuidV4() {
  final bytes = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
