// Add metrics.patty.io proxy host to CPM
// Upstream: http://10.200.47.187:9997 (Netdata on the Europe box, over NetBird)
import { Database } from "bun:sqlite";

const db = new Database("/data/caddy-proxy-manager.db");
const now = new Date().toISOString();

const host = {
  name: "Netdata Metrics (Europe box, 10.200.47.187:9997)",
  domains: JSON.stringify(["metrics.patty.io"]),
  upstreams: JSON.stringify(["http://10.200.47.187:9997"]),
};

// Skip if exists
const all = db.query("SELECT id, name, domains FROM proxy_hosts").all();
const dup = all.find((r) => {
  try { return JSON.parse(r.domains).includes(JSON.parse(host.domains)[0]); }
  catch (e) { return false; }
});

if (dup) {
  console.log("SKIP (already exists):", dup.name, "id=" + dup.id);
} else {
  db.query(
    `INSERT INTO proxy_hosts
      (name, domains, upstreams, certificateId, accessListId, ownerUserId,
       sslForced, hstsEnabled, hstsSubdomains, allowWebsocket, preserveHostHeader,
       meta, enabled, createdAt, updatedAt, skipHttpsHostnameValidation)
     VALUES (?, ?, ?, NULL, NULL, 1, 1, 1, 0, 1, 1, NULL, 1, ?, ?, 0)`
  ).run(host.name, host.domains, host.upstreams, now, now);
  const id = db.query("SELECT last_insert_rowid() as id").get().id;
  console.log("INSERTED:", host.name, "id=" + id, host.domains, "->", host.upstreams);
}

console.log("\nAll proxy_hosts:");
const final = db.query("SELECT id, name, domains, upstreams FROM proxy_hosts").all();
for (const r of final) {
  console.log("  -", r.name);
  console.log("    ", r.domains, "->", r.upstreams);
}
