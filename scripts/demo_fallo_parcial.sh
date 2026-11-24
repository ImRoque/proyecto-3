#!/usr/bin/env bash
# =============================================================================
# demo_fallo_parcial.sh — Demo de fallo parcial (docs/arquitectura.md, 5.3).
#
# Apaga un servicio (por defecto recomendar), prueba por el gateway las demás
# rutas (catálogo, consulta por folio y chat), muestra código HTTP y cuerpo de
# cada respuesta y vuelve a encender el servicio, aunque algo falle a medias.
#
# Uso (desde la raíz, con todo levantado: docker compose up -d):
#   ./scripts/demo_fallo_parcial.sh                # apaga recomendar
#   ./scripts/demo_fallo_parcial.sh pedidos        # apaga otro servicio
#
# Variables opcionales:
#   GATEWAY_URL   URL del gateway (por defecto http://localhost:8080)
#   FOLIO         folio existente; si no se da, se registra un pedido de prueba
# =============================================================================
set -euo pipefail

SERVICIO="${1:-recomendar}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8080}"
SERVICIOS="catalogo pedidos recomendar asistente"

case " $SERVICIOS " in
  *" $SERVICIO "*) ;;
  *) echo "Servicio no válido: $SERVICIO (usa: $SERVICIOS)" >&2; exit 1 ;;
esac

# Hace una petición por el gateway e imprime el código HTTP y el cuerpo.
# Uso: probar "<titulo>" <METODO> <ruta> [json] [encabezado extra]
probar() {
  local titulo="$1" metodo="$2" ruta="$3" cuerpo="${4:-}" encabezado="${5:-}"
  local args=(-s -m 15 -w '\n%{http_code} %{time_total}' -X "$metodo")
  if [ -n "$cuerpo" ]; then
    args+=(-H 'Content-Type: application/json' --data "$cuerpo")
  fi
  if [ -n "$encabezado" ]; then
    args+=(-H "$encabezado")
  fi
  local salida codigo tiempo
  salida="$(curl "${args[@]}" "$GATEWAY_URL$ruta" || true)"
  read -r codigo tiempo <<<"$(tail -n 1 <<<"$salida")"
  printf '\n> %s\n  %s %s -> HTTP %s (%.2f s)\n  %s\n' \
    "$titulo" "$metodo" "$ruta" "${codigo:-000}" "${tiempo:-0}" "$(sed '$d' <<<"$salida" | cut -c1-220)"
}

# UUID v4 para Idempotency-Key, sin depender de uuidgen ni python.
uuid4() {
  printf '%04x%04x-%04x-4%03x-%04x-%04x%04x%04x' \
    $RANDOM $RANDOM $RANDOM $((RANDOM & 0x0fff)) $(((RANDOM & 0x3fff) | 0x8000)) \
    $RANDOM $RANDOM $RANDOM
}

# Espera hasta que la ruta de salud del servicio responda 200 (máximo ~60 s).
esperar_salud() {
  local i
  for i in $(seq 1 30); do
    if [ "$(curl -s -o /dev/null -m 3 -w '%{http_code}' \
      "$GATEWAY_URL/api/$1/health/")" = "200" ]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

salud_de_todos() {
  local s
  for s in $SERVICIOS; do
    probar "Salud de $s" GET "/api/$s/health/"
  done
}

encender() {
  echo
  echo "=== Encendiendo $SERVICIO otra vez ==="
  docker compose start "$SERVICIO" >/dev/null 2>&1
  if esperar_salud "$SERVICIO"; then
    echo "$SERVICIO volvió a responder 200 sin reiniciar los demás."
  else
    echo "AVISO: $SERVICIO no respondió 200 tras encenderlo; revisa: docker compose logs $SERVICIO" >&2
  fi
  salud_de_todos
}

echo "=== Gateway: $GATEWAY_URL | servicio a apagar: $SERVICIO ==="

for s in $SERVICIOS; do
  if ! esperar_salud "$s"; then
    echo "El servicio $s no está sano. Levanta todo con: docker compose up -d" >&2
    exit 1
  fi
done
echo "Los cuatro servicios responden 200."

# Cuerpo de un pedido válido (docs/api.md, "Registrar un pedido").
fecha_limite="$(date -d '+30 days' +%F 2>/dev/null || date -v+30d +%F)"
pedido="{\"origen\": \"Av. Juarez 100, Guadalajara\", \"destino\": \"Calle Hidalgo 25, Zapopan\",
  \"distancia_km\": 8.5, \"peso_kg\": 2.3,
  \"dimensiones_cm\": {\"largo\": 30, \"ancho\": 20, \"alto\": 15},
  \"urgente\": false, \"seguro\": true, \"fecha_limite\": \"$fecha_limite\",
  \"medio\": \"motocicleta\", \"tipo_servicio\": \"express\"}"

# Folio para la consulta: se registra con todo encendido, antes de apagar nada.
if [ -z "${FOLIO:-}" ]; then
  respuesta="$(curl -s -m 15 -X POST "$GATEWAY_URL/api/pedidos/" \
    -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuid4)" --data "$pedido")"
  FOLIO="$(grep -o '"folio": *"[^"]*"' <<<"$respuesta" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
  if [ -z "$FOLIO" ]; then
    echo "No se pudo registrar el pedido de prueba: $respuesta" >&2
    exit 1
  fi
  echo "Pedido de prueba registrado: $FOLIO"
fi

echo
echo "=== Apagando $SERVICIO ==="
# Pase lo que pase después, el servicio se vuelve a encender al salir.
trap encender EXIT
docker compose stop "$SERVICIO" >/dev/null 2>&1
echo "$SERVICIO detenido."

echo
echo "=== Pruebas con $SERVICIO apagado ==="
salud_de_todos
probar "Catálogo: buscar medios" GET "/api/catalogo/medios/?q=moto"
probar "Consulta por folio" GET "/api/pedidos/$FOLIO/"
probar "Registrar pedido (pedidos consulta a catalogo)" POST "/api/pedidos/" \
  "$pedido" "Idempotency-Key: $(uuid4)"
probar "Recomendación directa" POST "/api/recomendar/" \
  '{"peso_kg": 3.5, "distancia_km": 6, "urgente": false,
    "dimensiones_cm": {"largo": 30, "ancho": 20, "alto": 15}}'
probar "Chat: saludo" POST "/api/asistente/" '{"mensaje": "Hola"}'
probar "Chat: rastrear (usa pedidos)" POST "/api/asistente/" \
  "{\"mensaje\": \"Donde esta mi pedido $FOLIO?\"}"
probar "Chat: recomendar (usa recomendar)" POST "/api/asistente/" \
  '{"mensaje": "Como mando 3 kg a 6 km, 30x20x15 cm, urgente?"}'
