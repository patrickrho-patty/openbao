#!/bin/sh
VAULT="https://secrets.patty.io"
KEYCLOAK="https://login.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
REALM="internal"
CLIENT_ID="openbao"
REDIRECT_URI="https://secrets.patty.io/ui/vault/auth/oidc/oidc/callback"

echo "============================================="
echo "TEST 1: Keycloak discovery document"
echo "============================================="
curl -sS --max-time 10 "$KEYCLOAK/realms/$REALM/.well-known/openid-configuration" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'  issuer: {d.get(\"issuer\")}')
print(f'  authorization_endpoint: {d.get(\"authorization_endpoint\")}')
print(f'  token_endpoint: {d.get(\"token_endpoint\")}')
print(f'  userinfo_endpoint: {d.get(\"userinfo_endpoint\")}')
print(f'  jwks_uri: {d.get(\"jwks_uri\")}')
print(f'  grant_types_supported: {d.get(\"grant_types_supported\")}')
"

echo
echo "============================================="
echo "TEST 2: OpenBao OIDC start URL (browser would do this)"
echo "============================================="
echo "  Hitting: $VAULT/ui/vault/auth/oidc/oidc/authorize?role=openbao&redirect_uri=$REDIRECT_URI"
echo
curl -sSI --max-time 10 $HOST "$VAULT/ui/vault/auth/oidc/oidc/authorize?role=openbao&redirect_uri=$REDIRECT_URI" 2>&1 | head -15

echo
echo "============================================="
echo "TEST 3: Try the v1 API equivalent"
echo "============================================="
curl -sSI --max-time 10 -H "X-Vault-Token: test" $HOST "$VAULT/v1/auth/oidc/oidc/auth?role=openbao&redirect_uri=$REDIRECT_URI" 2>&1 | head -10

echo
echo "============================================="
echo "TEST 4: Check if Keycloak is reachable from the OpenBao box"
echo "============================================="
docker exec openbao wget -qO- --timeout=10 "$KEYCLOAK/realms/$REALM/.well-known/openid-configuration" 2>/dev/null | head -c 200
echo
echo
echo "  (empty means OpenBao can NOT reach Keycloak directly — important)"

echo
echo "============================================="
echo "TEST 5: Use Keycloak's resource owner password grant (ROPG)"
echo "(requires 'Direct access grants' enabled on the openbao client)"
echo "============================================="
curl -sS --max-time 10 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=luFAhHIy9rd7saWqc440G0y73LIMG1bP" \
  -d "username=admin" \
  -d "password=admin" \
  -d "scope=openid profile email groups" \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" 2>&1 | head -c 500

echo
echo
echo "============================================="
echo "TEST 6: If ROPG works, exchange the token with OpenBao"
echo "============================================="
# Capture the access_token from the previous response
ACCESS_TOKEN=$(curl -sS --max-time 10 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=luFAhHIy9rd7saWqc440G0y73LIMG1bP" \
  -d "username=admin" \
  -d "password=admin" \
  -d "scope=openid profile email groups" \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('access_token', ''))
")
if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "None" ]; then
  echo "  Got Keycloak access token: ${ACCESS_TOKEN:0:30}..."
  echo
  echo "  Decoded JWT payload:"
  echo "$ACCESS_TOKEN" | cut -d. -f2 | python3 -c "
import sys, base64, json
s = sys.stdin.read().strip()
# pad base64
s += '=' * (-len(s) % 4)
print(json.dumps(json.loads(base64.urlsafe_b64decode(s)), indent=2))
"
  echo
  echo "  Exchanging with OpenBao OIDC callback..."
  # The callback endpoint expects a 'code' parameter, not a token
  # The proper way is to do the auth code flow, but for testing we can use the JWT directly
  # by calling /v1/auth/oidc/oidc/callback?code=...&state=...
  # However, ROPG tokens are typically used differently
  # Let's at least verify OpenBao can validate the Keycloak token
  echo
  echo "  Verifying OpenBao can talk to Keycloak's userinfo endpoint..."
  curl -sS --max-time 5 -H "Authorization: Bearer $ACCESS_TOKEN" "$KEYCLOAK/realms/$REALM/protocol/openid-connect/userinfo" 2>&1 | head -c 300
  echo
else
  echo "  (no access token from ROPG — 'Direct access grants' probably not enabled on the client)"
fi
