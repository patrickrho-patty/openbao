#!/bin/sh
. /tmp/openbao-creds.sh
VAULT="https://secrets.patty.io"
HOST="--resolve secrets.patty.io:443:10.200.85.232"

echo "=== Trace redirect chain from root ==="
curl -sSIL --max-time 10 $HOST "$VAULT/" 2>&1 | grep -iE "HTTP|location:" | head -10
echo
echo "=== From /ui/ (where OpenBau redirects) ==="
curl -sSIL --max-time 10 $HOST "$VAULT/ui/" 2>&1 | grep -iE "HTTP|location:" | head -10
echo
echo "=== From /ui/vault/auth ==="
curl -sSIL --max-time 10 $HOST "$VAULT/ui/vault/auth" 2>&1 | grep -iE "HTTP|location:" | head -10
echo
echo "=== Look for 'with=' parameter in any redirect URL ==="
curl -sSIL --max-time 10 $HOST "$VAULT/ui/vault/auth" 2>&1 | grep -oE "with=[a-z_]+" | head -3
echo
echo "=== Fetch the auth page body and look for the selected method ==="
curl -sS --max-time 5 $HOST "$VAULT/ui/vault/auth" 2>&1 | grep -oE "with=[a-z_]+" | head -3
curl -sS --max-time 5 $HOST "$VAULT/ui/vault/auth" 2>&1 | grep -oE "/_?oidc[^\"' ]*" | head -3
