#!/usr/bin/env bash
# CTO demo: Hamza's order from start to finish, through the API gateway ONLY (port 3000),
# plus the two failure cases. Every "CHECK" is a real assertion; the script exits non-zero if any fails.
# Needs only bash + curl. Safe to run repeatedly (it compares before/after, not fixed numbers).
set -u
GW="${GATEWAY:-http://localhost:3000}"
FAILS=0
BODY=""; CODE=""

hdr()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
call() { # METHOD PATH [JSON]  -> sets BODY and CODE, prints the exchange
  local out
  if [ $# -ge 3 ]; then out=$(curl -s -w '\n%{http_code}' -X "$1" -H 'Content-Type: application/json' -d "$3" "$GW$2")
  else out=$(curl -s -w '\n%{http_code}' -X "$1" "$GW$2"); fi
  CODE=$(printf '%s' "$out" | tail -n1); BODY=$(printf '%s' "$out" | sed '$d')
  printf '  %s %s%s\n  -> HTTP %s  %s\n' "$1" "$2" "${3:+  $3}" "$CODE" "$BODY"
}
num()  { printf '%s' "$BODY" | sed -n 's/.*"'"$1"'":\([0-9.]*\).*/\1/p' | head -1; }
str()  { printf '%s' "$BODY" | sed -n 's/.*"'"$1"'":"\([^"]*\)".*/\1/p' | head -1; }
count(){ printf '%s' "$BODY" | grep -o "\"$1\"" | wc -l | tr -d ' '; }
check(){ if [ "$2" = "$3" ]; then printf '  \033[32mCHECK PASS\033[0m  %s (%s)\n' "$1" "$3"; else printf '  \033[31mCHECK FAIL\033[0m  %s (expected %s, got %s)\n' "$1" "$2" "$3"; FAILS=$((FAILS+1)); fi; }
snapshot() { # sets P (Hamza points), S101, S102, S104 (stock), NORD, NPAY
  call GET /customers/C-1042 >/dev/null; P=$(num loyaltyPoints)
  call GET /inventory/M-101 >/dev/null;  S101=$(num quantity)
  call GET /inventory/M-102 >/dev/null;  S102=$(num quantity)
  call GET /inventory/M-104 >/dev/null;  S104=$(num quantity)
  call GET /orders   >/dev/null; NORD=$(count orderId)
  call GET /payments >/dev/null; NPAY=$(count paymentId)
}

hdr "0. The platform is up (gateway is the single public entry point)"
call GET /health; check "gateway healthy" 200 "$CODE"

hdr "1. Hamza browses the menu"
call GET /menu; check "menu returned" 200 "$CODE"

hdr "2. Hamza checks his loyalty points"
call GET /customers/C-1042; check "customer found" 200 "$CODE"
P0=$(num loyaltyPoints); echo "  Hamza has $P0 points"
snapshot; S101_0=$S101; S102_0=$S102; P_0=$P; NORD0=$NORD; NPAY0=$NPAY

hdr "3. Hamza orders 1 Zinger Burger (Rs.450) + 1 Fries (Rs.200)"
call POST /orders '{"customerId":"C-1042","items":[{"itemId":"M-101","quantity":1},{"itemId":"M-102","quantity":1}]}'
check "order accepted" 201 "$CODE"; check "order total" 650 "$(num total)"; check "status CONFIRMED" CONFIRMED "$(str status)"
ORDER_ID=$(str orderId); echo "  order id: $ORDER_ID"

hdr "4. Stock and loyalty points changed along the way"
snapshot
check "Zinger stock went down by 1" $((S101_0-1)) "$S101"
check "Fries stock went down by 1"  $((S102_0-1)) "$S102"
check "Hamza earned 65 points (1 per Rs.10)" $((P_0+65)) "$P"
check "one new order stored" $((NORD0+1)) "$NORD"

hdr "5. Hamza pays the exact amount"
call POST /payments "{\"orderId\":\"$ORDER_ID\",\"amount\":650}"
check "payment accepted" 201 "$CODE"; check "confirmation message" "Payment successful" "$(str message)"
echo "  payment id: $(str paymentId)"
call GET "/orders/$ORDER_ID" >/dev/null; check "order is now PAID" PAID "$(str status)"
snapshot; check "one payment recorded" $((NPAY0+1)) "$NPAY"

hdr "FAILURE CASE A: order for more items than are in stock"
snapshot; P_A=$P; S_A=$S101; N_A=$NORD; PAY_A=$NPAY
call POST /orders '{"customerId":"C-1042","items":[{"itemId":"M-101","quantity":1000}]}'
check "order refused (409 conflict)" 409 "$CODE"
snapshot
check "stock NOT deducted"        "$S_A" "$S101"
check "points NOT awarded"        "$P_A" "$P"
check "no order recorded"         "$N_A" "$NORD"
check "no payment recorded"       "$PAY_A" "$NPAY"

hdr "FAILURE CASE B: payment whose amount does not match the order"
call POST /orders '{"customerId":"C-1042","items":[{"itemId":"M-104","quantity":1}]}'
check "order for 1 Chai (Rs.80) accepted" 201 "$CODE"; B_ORDER=$(str orderId)
snapshot; P_B=$P; PAY_B=$NPAY
call POST /payments "{\"orderId\":\"$B_ORDER\",\"amount\":50}"
check "payment refused (400)" 400 "$CODE"
call GET "/payments/$B_ORDER" >/dev/null; check "no payment record for that order" 404 "$CODE"
call GET "/orders/$B_ORDER" >/dev/null;   check "order is still CONFIRMED, not PAID" CONFIRMED "$(str status)"
snapshot
check "payments total unchanged" "$PAY_B" "$NPAY"
check "points unchanged by the failed payment" "$P_B" "$P"
echo "  ...and the correct amount still works afterwards:"
call POST /payments "{\"orderId\":\"$B_ORDER\",\"amount\":80}"; check "correct payment accepted" 201 "$CODE"

echo
if [ $FAILS -eq 0 ]; then printf '\033[32mDEMO RESULT: ALL CHECKS PASSED\033[0m\n'; else printf '\033[31mDEMO RESULT: %s CHECK(S) FAILED\033[0m\n' $FAILS; fi
exit $FAILS
