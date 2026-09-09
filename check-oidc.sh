#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
H="X-Vault-Token: $BAO_ROOT_TOKEN"

echo "=== Auth methods ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/auth | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    if isinstance(v, dict):
        print('  ' + k + '  type=' + str(v.get('type', '?')))
"

echo
echo "=== OIDC config (key fields) ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/config 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = ['oidc_discovery_url','oidc_client_id','default_policy','default_role','oidc_scopes','claim_mappings']
for k in keys:
    print('  ' + k + ': ' + str(d.get(k)))
"

echo
echo "=== OIDC roles ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/role 2>/dev/null | python3 -m json.tool

echo
echo "=== Test direct OIDC start URL ==="
curl -sSI --max-time 5 $HOST "$VAULT/v1/auth/oidc/oidc/auth?role=openbao" 2>&1 | head -8

echo
echo "=== Test the UI OIDC callback path ==="
curl -sSI --max-time 5 $HOST "$VAULT/ui/vault/auth/oidc/oidc/callback?role=openbao" 2>&1 | head -8
