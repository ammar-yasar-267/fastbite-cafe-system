#!/usr/bin/env bash
# Shows that the data is still there after the platform is stopped, removed and started again.
# Run from the repo root. Needs docker compose + curl.
set -u
cd "$(dirname "$0")/.."
GW="${GATEWAY:-http://localhost:3000}"
state() {
  printf 'Hamza points=%s | Zinger stock=%s | orders=%s | payments=%s\n' \
    "$(curl -s $GW/customers/C-1042 | sed -n 's/.*"loyaltyPoints":\([0-9]*\).*/\1/p')" \
    "$(curl -s $GW/inventory/M-101 | sed -n 's/.*"quantity":\([0-9]*\).*/\1/p')" \
    "$(curl -s $GW/orders | grep -o '"orderId"' | wc -l | tr -d ' ')" \
    "$(curl -s $GW/payments | grep -o '"paymentId"' | wc -l | tr -d ' ')"
}
fails=0
verify() { after=$(state); echo "AFTER : $after"; if [ "$after" = "$before" ]; then echo "  PASS - identical, the data survived"; else echo "  FAIL - data changed"; fails=1; fi; }

before=$(state); echo "BEFORE: $before"

echo; echo ">> docker compose stop, then start (containers stopped and restarted)"
docker compose stop >/dev/null 2>&1; docker compose start >/dev/null 2>&1; docker compose up -d --wait >/dev/null 2>&1
verify

echo; echo ">> docker compose down (ALL containers REMOVED), then up (brand-new containers)"
docker compose down 2>&1 | tail -3
docker volume ls --format '{{.Name}}' | grep mongo-data | sed 's/^/   volume still exists: /'
docker compose up -d --wait >/dev/null 2>&1
verify

echo; echo ">> remove ONLY the database container and recreate it"
docker compose rm -sf mongo >/dev/null 2>&1; docker compose up -d --wait >/dev/null 2>&1
verify
exit $fails
