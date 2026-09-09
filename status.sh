#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
H="X-Vault-Token: $BAO_ROOT_TOKEN"

echo "=== 1. Health ==="
curl -sS --max-time 5 $HOST $VAULT/v1/sys/health | python3 -m json.tool

echo
echo "=== 2. Auth methods ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/sys/auth 2>/dev/null \
  | python3 -c "import json,sys; print('  ', list(json.load(sys.stdin).keys())[:6])"

echo
echo "=== 3. OIDC config ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/config 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'  {k}: {d.get(k)}') for k in ['oidc_discovery_url','oidc_client_id','default_policy','oidc_scopes']]"

echo
echo "=== 4. OIDC role (openbao) ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/role/openbao 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['data']; [print(f'  {k}: {d.get(k)}') for k in ['user_claim','bound_audiences','policies','claim_mappings']]"

echo
echo "=== 5. Policies ==="
curl -sS --max-time 5 $HOST -H "$H" "$VAULT/v1/sys/policies/acl?list=true" 2>/dev/null \
  | python3 -c "import json,sys; print('  ', json.load(sys.stdin)['data']['keys'])"

echo
echo "=== 6. External groups ==="
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/identity/group/name 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['data']; [print(f'  {k}: policies={v.get(\"policies\",[])}') for k,v in d.items() if isinstance(v, dict)]"
