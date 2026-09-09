#!/bin/sh
echo "=== Is garm.patty.io in CPM? ==="
docker exec caddy-proxy-manager bun -e '
import { Database } from "bun:sqlite";
const db = new Database("/data/caddy-proxy-manager.db", { readonly: true });
const rows = db.query("SELECT name, domains, upstreams FROM proxy_hosts").all();
for (const r of rows) {
  console.log("  -", r.name, "|", r.domains, "|", r.upstreams);
}
const garm = rows.find(r => r.domains.includes("garm"));
console.log("");
console.log("  garm.patty.io in CPM:", garm ? "YES (still there)" : "NO (correctly removed)");
'
echo
echo "=== Cert still in Caddy storage? ==="
ls /opt/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ 2>/dev/null
echo
echo "=== Public DNS for garm.patty.io ==="
curl -sS --max-time 10 "https://cloudflare-dns.com/dns-query?name=garm.patty.io&type=A" \
  -H "accept: application/dns-json" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('Answer', []):
    print('  A ->', a.get('data', '?'))
"
echo
echo "=== Test reachability from Japan box ==="
for ip in 10.200.85.232 10.200.47.187 109.123.231.227; do
  R=$(curl -k -sS --max-time 5 --resolve garm.patty.io:443:$ip -o /dev/null -w "HTTP %{http_code}" "https://garm.patty.io/" 2>&1)
  echo "  $ip -> $R"
done
