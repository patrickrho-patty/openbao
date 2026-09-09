// Add garm.patty.io proxy host to CPM
// Upstream: http://10.200.85.232:9997 (garm on this same host, bound to 0.0.0.0)
import { Database } from "bun:sqlite";

const db = new Database("/data/caddy-proxy-manager.db");
const now = new Date().toISOString();

const host = {
  name: "GARM GitHub Runner Manager (local, port 9997)",
  domains: JSON.stringify(["garm.patty.io"]),
  upstreams: JSON.stringify(["http://10.200.85.232:9997"]),
};

const all = db.query("SELECT id, name, domains FROM proxy_hosts").all();
const dup = all.find((r) => {
  try { return JSON.parse(r.domains).includes(JSON.parse(host.domains)[0]); }
  catch (e) { return false; }
});

if (dup) {
  console.log("SKIP:", dup.name);
} else {
  db.query(
    `INSERT INTO proxy_hosts
      (name, domains, upstreams, certificateId, accessListId, ownerUserId,
       sslForced, hstsEnabled, hstsSubdomains, allowWebsocket, preserveHostHeader,
       meta, enabled, createdAt, updatedAt, skipHttpsHostnameValidation)
     VALUES (?, ?, ?, NULL, NULL, 1, 1, 1, 0, 1, 1, NULL, 1, ?, ?, 0)`
  ).run(host.name, host.domains, host.upstreams, now, now);
  const id = db.query("SELECT last_insert_rowid() as id").get().id;
  console.log("INSERTED:", host.name, "id=" + id);
}

console.log("\nAll proxy_hosts:");
const final = db.query("SELECT name, domains, upstreams FROM proxy_hosts").all();
for (const r of final) {
  console.log(`  - ${r.name}`);
  console.log(`    ${r.domains} -> ${r.upstreams}`);
}
