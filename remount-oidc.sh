#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
H="X-Vault-Token: $BAO_ROOT_TOKEN"

echo "=== Step 1: Disable OIDC at oidc/ (preserves the config we need to re-apply) ==="
# Read current config first
echo "  current OIDC config (for reference):"
docker exec -e BAO_ADDR=http://localhost:8200 -e BAO_TOKEN="$BAO_ROOT_TOKEN" openbao \
  bao read -format=json auth/oidc/config 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin).get('data', {})
print(f'    discovery_url: {d.get(\"oidc_discovery_url\")}')
print(f'    client_id:     {d.get(\"oidc_client_id\")}')
print(f'    default_policy: {d.get(\"default_policy\")}')
print(f'    default_role:   {d.get(\"default_role\")}')
print(f'    scopes:        {d.get(\"oidc_scopes\")}')
"

echo
echo "=== Step 2: Disable OIDC at oidc/ ==="
curl -sS --max-time 10 -X DELETE $HOST -H "$H" $VAULT/v1/sys/auth/oidc
echo "  ✓ disabled"

echo
echo "=== Step 3: Enable OIDC at _oidc/ (sorts before token/) ==="
curl -sS --max-time 10 -X POST $HOST -H "$H" \
  -d '{"type":"oidc","description":"OIDC via Keycloak (login.patty.io)"}' \
  $VAULT/v1/sys/auth/_oidc
echo "  ✓ enabled at _oidc/"

echo
echo "=== Step 4: Configure OIDC at _oidc/ ==="
cat > /tmp/oidc-cfg3.json <<'JSON'
{
  "oidc_discovery_url": "https://login.patty.io/realms/internal",
  "oidc_client_id": "openbao",
  "oidc_client_secret": "luFAhHIy9rd7saWqc440G0y73LIMG1bP",
  "default_policy": "oidc-default",
  "default_role": "openbao",
  "oidc_scopes": ["openid","profile","email","groups"]
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-cfg3.json $VAULT/v1/auth/_oidc/config
echo
echo "  ✓ configured"

echo
echo "=== Step 5: Re-create the OIDC role at _oidc/ ==="
cat > /tmp/oidc-role3.json <<'JSON'
{
  "allowed_redirect_uris": [
    "https://secrets.patty.io/oidc/callback",
    "https://secrets.patty.io/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8200/ui/vault/auth/oidc/oidc/callback"
  ],
  "user_claim": "email",
  "bound_audiences": ["openbao"],
  "policies": ["oidc-default"],
  "claim_mappings": {"groups": "groups"}
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-role3.json $VAULT/v1/auth/_oidc/role/openbao
echo
echo "  ✓ role created"

echo
echo "=== Step 6: Verify — list auth methods (token/ should still be there, _oidc/ should be FIRST) ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/auth | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    if isinstance(v, dict):
        t = v.get('type', '?')
        print(f'  {k:20s}  type={t}')
"

echo
echo "=== Step 7: Confirm group mapping still in place (path doesn't matter for groups) ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/identity/group/name/patty-admin 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin).get('data', {})
print(f'  patty-admin: policies={d.get(\"policies\")}, type={d.get(\"type\")}')
"

echo
echo "=== Step 8: Simulate browser visit to root (should now redirect to OIDC) ==="
curl -sSIL --max-time 5 $HOST "$VAULT/" 2>&1 | grep -iE "location|HTTP/" | head -5
