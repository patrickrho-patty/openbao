#!/bin/sh
VAULT="https://secrets.patty.io"
KEYCLOAK="https://login.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
REALM="internal"
CLIENT_ID="openbao"
REDIRECT_URI="https://secrets.patty.io/ui/vault/auth/oidc/oidc/callback"

echo "================================================="
echo "TEST A: Trace full OIDC redirect chain"
echo "================================================="
echo "Hitting: $VAULT/ui/vault/auth/oidc/oidc/authorize"
echo "  with role=openbao&redirect_uri=$REDIRECT_URI"
echo
curl -sSIL --max-time 10 $HOST \
  "$VAULT/ui/vault/auth/oidc/oidc/authorize?role=openbao&redirect_uri=$REDIRECT_URI" 2>&1 \
  | grep -iE "^location:|HTTP/|^<" | head -10

echo
echo "================================================="
echo "TEST B: Direct Keycloak login page (no auth required to view)"
echo "================================================="
curl -sS --max-time 10 \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/auth?client_id=$CLIENT_ID&redirect_uri=$REDIRECT_URI&response_type=code&scope=openid&state=test123" 2>&1 \
  | grep -oE 'name="code"|<title>[^<]+</title>|action="[^"]*"|<input[^>]*name="username"|kc-form-login|kc-form-options' \
  | head -5

echo
echo "================================================="
echo "TEST C: Full OIDC flow - get the auth code (simulate)"
echo "We need to actually log in. Try a known user via REST API."
echo "================================================="
# Try client credentials grant (service account, not user)
echo "  --- client_credentials grant (service account) ---"
curl -sS --max-time 10 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=luFAhHIy9rd7saWqc440G0y73LIMG1bP" \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" 2>&1 | head -c 400
echo
echo
echo "  --- authorization_code with wrong code (should error gracefully) ---"
curl -sS --max-time 10 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=luFAhHIy9rd7saWqc440G0y73LIMG1bP" \
  -d "code=fake-code" \
  -d "redirect_uri=$REDIRECT_URI" \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" 2>&1 | head -c 300
echo
echo
echo "  --- If that returns 'invalid_grant', it means the endpoint exists, configured correctly."
echo "  --- A real auth code from a real login would work."

echo
echo "================================================="
echo "TEST D: Check JWKS endpoint (OpenBao needs this to validate JWTs)"
echo "================================================="
curl -sS --max-time 5 "$KEYCLOAK/realms/$REALM/protocol/openid-connect/certs" 2>&1 | python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = d.get('keys', [])
print(f'  JWKS has {len(keys)} key(s)')
if keys:
    k = keys[0]
    print(f'  First key: kid={k.get(\"kid\", \"?\")[:20]} alg={k.get(\"alg\")} kty={k.get(\"kty\")}')
" 2>&1 | head -5

echo
echo "================================================="
echo "TEST E: Final summary"
echo "================================================="
echo "  Keycloak reachable from box:        $(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' $KEYCLOAK/realms/$REALM/.well-known/openid-configuration 2>/dev/null || echo 'NO')"
echo "  OpenBao OIDC config status:           $(docker exec -e BAO_ADDR=http://localhost:8200 -e BAO_TOKEN=$(jq -r .root_token /opt/openbao/init-response.json) openbao bao read -format=json auth/oidc/config 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"data\",{}).get(\"status\",\"?\"))' 2>/dev/null || echo '?')"
echo "  OIDC role 'openbao' exists:           $(docker exec -e BAO_ADDR=http://localhost:8200 -e BAO_TOKEN=$(jq -r .root_token /opt/openbao/init-response.json) openbao bao read -format=json auth/oidc/role/openbao 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin).get(\"data\",{}); print(\"yes - \" + str(d.get(\"bound_audiences\",\"?\")))' 2>/dev/null || echo '?')"
echo "  Group 'patty-admin' -> openbao-admin:  $(docker exec -e BAO_ADDR=http://localhost:8200 -e BAO_TOKEN=$(jq -r .root_token /opt/openbao/init-response.json) openbao bao list identity/group/name 2>/dev/null | grep patty-admin || echo '?')"
echo "  Reachability from browser via NetBird: user must add secrets.patty.io -> 10.200.85.232 zone in NetBird DNS"
