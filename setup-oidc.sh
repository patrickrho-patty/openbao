#!/bin/sh
set -eu
VAULT="https://secrets.patty.io"
. /tmp/openbao-creds.sh
H="X-Vault-Token: $BAO_ROOT_TOKEN"
HOST="--resolve secrets.patty.io:443:10.200.85.232"

# [1] Enable OIDC auth method
echo "=== Enable OIDC auth method ==="
curl -sS --max-time 10 -X POST $HOST -H "$H" \
  -d '{"type":"oidc","description":"OIDC via Keycloak (login.patty.io)"}' \
  $VAULT/v1/sys/auth/oidc
echo

# [2] Configure OIDC with Keycloak
echo "=== Configure OIDC ==="
cat > /tmp/oidc-config.json <<'JSON'
{
  "oidc_discovery_url": "https://login.patty.io/realms/internal",
  "oidc_client_id": "openbao",
  "oidc_client_secret": "luFAhHIy9rd7saWqc440G0y73LIMG1bP",
  "default_policy": "oidc-default",
  "oidc_scopes": ["openid","profile","email","groups"]
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-config.json \
  $VAULT/v1/auth/oidc/config
echo

# [3] Create OIDC role
echo "=== Create OIDC role ==="
cat > /tmp/oidc-role.json <<'JSON'
{
  "allowed_redirect_uris": [
    "https://secrets.patty.io/oidc/callback",
    "https://secrets.patty.io/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8200/ui/vault/auth/oidc/oidc/callback"
  ],
  "user_claim": "email",
  "bound_audiences": ["openbao"],
  "policies": ["oidc-default"],
  "claim_mappings": {
    "groups": "groups"
  }
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/oidc-role.json \
  $VAULT/v1/auth/oidc/role/openbao
echo

# [4] Create policies
echo "=== Create policies ==="
cat > /tmp/pol-default.hcl <<'HCL'
path "auth/token/lookup-self" { capabilities = ["read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
HCL
curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/pol-default.hcl \
  $VAULT/v1/sys/policies/acl/oidc-default
echo "  oidc-default OK"

cat > /tmp/pol-admin.hcl <<'HCL'
path "*" { capabilities = ["create","read","update","delete","list","sudo"] }
HCL
curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/pol-admin.hcl \
  $VAULT/v1/sys/policies/acl/openbao-admin
echo "  openbao-admin OK"

cat > /tmp/pol-writer.hcl <<'HCL'
path "secret/data/applications/*" { capabilities = ["create","read","update"] }
path "secret/metadata/applications/*" { capabilities = ["list","read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
HCL
curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/pol-writer.hcl \
  $VAULT/v1/sys/policies/acl/openbao-writer
echo "  openbao-writer OK"

# [5] Map Keycloak group
echo "=== Map Keycloak group patty-admin -> openbao-admin ==="
cat > /tmp/group.json <<'JSON'
{
  "policies": ["openbao-admin"],
  "type": "external"
}
JSON
curl -sS --max-time 10 -X POST $HOST -H "$H" --data @/tmp/group.json \
  $VAULT/v1/identity/group/name/patty-admin
echo

# Verify
echo
echo "=== Verify ==="
echo "  auth methods:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/auth 2>/dev/null | python3 -c "import json,sys; print('   ', list(json.load(sys.stdin).keys()))"
echo "  policies:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/policies/acl 2>/dev/null | python3 -c "import json,sys; print('   ', json.load(sys.stdin)['keys'])"
echo "  external groups:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/identity/group/name 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('   ', {k: v.get('policies',[]) for k,v in d.items()})"
echo
echo "  OIDC config:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/config 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('   oidc_client_id:', d.get('oidc_client_id')); print('   oidc_discovery_url:', d.get('oidc_discovery_url')); print('   default_policy:', d.get('default_policy'))"
