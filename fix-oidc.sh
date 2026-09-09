#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
H="X-Vault-Token: $BAO_ROOT_TOKEN"

echo "=== Re-configure OIDC with default_role so the UI shows it ==="
cat > /tmp/oidc-cfg2.json <<'JSON'
{
  "oidc_discovery_url": "https://login.patty.io/realms/internal",
  "oidc_client_id": "openbao",
  "oidc_client_secret": "luFAhHIy9rd7saWqc440G0y73LIMG1bP",
  "default_policy": "oidc-default",
  "default_role": "openbao",
  "oidc_scopes": ["openid","profile","email","groups"]
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-cfg2.json $VAULT/v1/auth/oidc/config
echo
echo "  ✓ re-configured with default_role=openbao"

echo
echo "=== Verify the OIDC role has correct settings ==="
cat > /tmp/oidc-role2.json <<'JSON'
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
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-role2.json $VAULT/v1/auth/oidc/role/openbao
echo
echo "  ✓ role re-saved"

echo
echo "=== Verify config is now persisted ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/config 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('  oidc_discovery_url:', d.get('oidc_discovery_url'))
print('  oidc_client_id:', d.get('oidc_client_id'))
print('  default_policy:', d.get('default_policy'))
print('  default_role:', d.get('default_role'))
print('  status:', d.get('status'))
"

echo
echo "=== Test direct OIDC start (should now redirect to Keycloak) ==="
curl -sSI --max-time 5 $HOST "$VAULT/v1/auth/oidc/oidc/auth?role=openbao" 2>&1 | head -8
