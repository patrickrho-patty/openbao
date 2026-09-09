#!/bin/sh
CPM_IP=$1
SESSION_TOKEN=$2

echo "=== Try 1: cookie 'better-auth.session_token' ==="
curl -sS -w "\nHTTP %{http_code}\n" -b "better-auth.session_token=$SESSION_TOKEN" \
  "http://$CPM_IP:3000/api/v1/users/me"

echo ""
echo "=== Try 2: cookie 'session_token' ==="
curl -sS -w "\nHTTP %{http_code}\n" -b "session_token=$SESSION_TOKEN" \
  "http://$CPM_IP:3000/api/v1/users/me"

echo ""
echo "=== Try 3: Bearer header ==="
curl -sS -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer $SESSION_TOKEN" \
  "http://$CPM_IP:3000/api/v1/users/me"

echo ""
echo "=== Try 4: cookie 'session' ==="
curl -sS -w "\nHTTP %{http_code}\n" -b "session=$SESSION_TOKEN" \
  "http://$CPM_IP:3000/api/v1/users/me"
