#!/usr/bin/env bash
# STEP 1 PROOF: before packaging anything, show that the inherited code starts
# and answers on its own port. Needs node, npm and mongod installed locally.
# Uses a throw-away MongoDB on port 27018 so it never touches real data.
set -u
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
MPORT=27018
PIDS=""
cleanup() { for p in $PIDS; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done; wait 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$WORK/db"
mongod --dbpath "$WORK/db" --port $MPORT --bind_ip 127.0.0.1 >"$WORK/mongod.log" 2>&1 &
PIDS="$PIDS $!"
sleep 3

# service:port:database   (works on old bash 3.2 too)
SERVICES="menu-service:3001:fastbite_menu order-service:3002:fastbite_orders inventory-service:3003:fastbite_inventory customer-service:3004:fastbite_customers payment-service:3005:fastbite_payments api-gateway:3000:none"

for entry in $SERVICES; do
  svc=${entry%%:*}; rest=${entry#*:}; db=${rest#*:}
  (cd "$svc" && npm install --silent --no-audit --no-fund >/dev/null 2>&1)
  ( cd "$svc" && MONGO_URI="mongodb://127.0.0.1:$MPORT/$db" npm start >"$WORK/$svc.log" 2>&1 ) &
  PIDS="$PIDS $!"
done
sleep 6

fail=0
for entry in $SERVICES; do
  svc=${entry%%:*}; rest=${entry#*:}; port=${rest%%:*}
  out=$(curl -s -m 3 "http://127.0.0.1:$port/health")
  if [[ "$out" == *'"status":"ok"'* ]]; then echo "PASS  $svc  port $port  -> $out"
  else echo "FAIL  $svc  port $port  -> '$out'"; tail -3 "$WORK/$svc.log"; fail=1; fi
done
echo "--- gateway forwards to a real service (GET /menu):"
curl -s -m 3 http://127.0.0.1:3000/menu | head -c 220; echo
exit $fail
