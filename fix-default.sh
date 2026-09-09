#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"
H="X-Vault-Token: $BAO_ROOT_TOKEN"

echo "=== Set token method to hidden in UI listing ==="
echo "(token still works for API access via X-Vault-Token header)"
curl -sS --max-time 10 -X POST $HOST -H "$H" \
  -d '{"listing_visibility":"hidden"}' \
  $VAULT/v1/auth/token/tune
echo
echo "  ✓ token hidden from login UI"

echo
echo "=== Ensure OIDC is visible to unauthenticated users ==="
curl -sS --max-time 10 -X POST $HOST -H "$H" \
  -d '{"listing_visibility":"unauth"}' \
  $VAULT/v1/auth/oidc/tune
echo
echo "  ✓ OIDC visible to login screen"

echo
echo "=== Verify the tune took effect ==="
echo "  token listing_visibility:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/token/tune 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('   ', d.get('listing_visibility', '?'))
"
echo "  oidc listing_visibility:"
curl -sS --max-time 5 $HOST -H "$H" $VAULT/v1/auth/oidc/tune 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('   ', d.get('listing_visibility', '?'))
"

echo
echo "=== Simulate a browser visit to the root ==="
echo "  (this is what happens when the user goes to https://secrets.patty.io/)"
curl -sSIL --max-time 5 $HOST "$VAULT/" 2>&1 | head -10
