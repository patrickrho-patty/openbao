#!/bin/sh
set -eu
VAULT="https://secrets.patty.io"
. /tmp/openbao-creds.sh
H="X-Vault-Token: $BAO_ROOT_TOKEN"
HOST="--resolve secrets.patty.io:443:10.200.85.232"

# Create policies - OpenBau expects {"policy": "<hcl content>"}

echo "=== oidc-default ==="
HCL='path "auth/token/lookup-self" { capabilities = ["read"] }
path "auth/token/renew-self" { capabilities = ["update"] }'
python3 -c "import json,os; print(json.dumps({'policy': os.environ['HCL']}))" > /tmp/p.json
HCL="$HCL" curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/p.json $VAULT/v1/sys/policies/acl/oidc-default
echo

echo "=== openbao-admin ==="
HCL='path "*" { capabilities = ["create","read","update","delete","list","sudo"] }'
python3 -c "import json,os; print(json.dumps({'policy': os.environ['HCL']}))" > /tmp/p.json
HCL="$HCL" curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/p.json $VAULT/v1/sys/policies/acl/openbao-admin
echo

echo "=== openbao-writer ==="
HCL='path "secret/data/applications/*" { capabilities = ["create","read","update"] }
path "secret/metadata/applications/*" { capabilities = ["list","read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
path "auth/token/lookup-self" { capabilities = ["read"] }'
python3 -c "import json,os; print(json.dumps({'policy': os.environ['HCL']}))" > /tmp/p.json
HCL="$HCL" curl -sS --max-time 10 -X PUT $HOST -H "$H" --data @/tmp/p.json $VAULT/v1/sys/policies/acl/openbao-writer
echo

echo
echo "=== Verify policies ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/policies/acl 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('  policies:', list(d.get('keys', d)))"
echo
echo "=== Verify oidc-default policy content ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/policies/acl/oidc-default | python3 -m json.tool
