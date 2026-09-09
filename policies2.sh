#!/bin/sh
set -eu
VAULT="https://secrets.patty.io"
. /tmp/openbao-creds.sh
H="X-Vault-Token: $BAO_ROOT_TOKEN"
HOST="--resolve secrets.patty.io:443:10.200.85.232"

# Use jq to wrap HCL in {"policy": "..."} JSON
which jq >/dev/null || apt-get install -y jq >/dev/null 2>&1 || true

put_policy() {
  local name="$1"
  local hcl="$2"
  echo "$hcl" | jq -Rs '{policy: .}' > /tmp/p.json
  echo "=== $name ==="
  curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/p.json $VAULT/v1/sys/policies/acl/$name
  echo
}

put_policy "oidc-default" 'path "auth/token/lookup-self" { capabilities = ["read"] }
path "auth/token/renew-self" { capabilities = ["update"] }'

put_policy "openbao-admin" 'path "*" { capabilities = ["create","read","update","delete","list","sudo"] }'

put_policy "openbao-writer" 'path "secret/data/applications/*" { capabilities = ["create","read","update"] }
path "secret/metadata/applications/*" { capabilities = ["list","read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
path "auth/token/lookup-self" { capabilities = ["read"] }'

echo "=== Verify ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/policies/acl 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('  policies:', list(d.get('keys', {})))"
echo
echo "=== External groups (with mapped policies) ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/identity/group/name 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k,v in d.items():
    if isinstance(v, dict):
        print(f'  {k}: policies={v.get(\"policies\",[])}')
"
