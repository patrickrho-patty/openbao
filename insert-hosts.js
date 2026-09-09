// Insert two proxy hosts into CPM DB, then exit
// CPM will apply to Caddy on next startup (we restart it after)
import { Database } from "bun:sqlite";

const db = new Database("/data/caddy-proxy-manager.db");

const now = new Date().toISOString();

const hosts = [
  {
    name: "Caddy Manager UI",
    domains: JSON.stringify(["caddy.patty.io"]),
    upstreams: JSON.stringify(["http://cpm:3000"]),
  },
  {
    name: "OmniRoute",
    domains: JSON.stringify(["omni.patty.io"]),
    upstreams: JSON.stringify(["http://omniroute:20128"]),
  },
];

for (const h of hosts) {
  // Skip if already present
  const existing = db
    .query("SELECT id FROM proxy_hosts WHERE domains LIKE ?")
    .all("%" + h.name + "%");
  // Actually search by domain
  const all = db.query("SELECT id, name, domains FROM proxy_hosts").all();
  const dup = all.find((r) => {
    try {
      return JSON.parse(r.domains).includes(JSON.parse(h.domains)[0]);
    } catch (e) {
      return false;
    }
  });
  if (dup) {
    console.log("SKIP (already exists):", dup.name, "id=" + dup.id, dup.domains);
    continue;
  }

  db.query(
    `INSERT INTO proxy_hosts
      (name, domains, upstreams, certificateId, accessListId, ownerUserId,
       sslForced, hstsEnabled, hstsSubdomains, allowWebsocket, preserveHostHeader,
       meta, enabled, createdAt, updatedAt, skipHttpsHostnameValidation)
     VALUES (?, ?, ?, NULL, NULL, 1, 1, 1, 0, 1, 1, NULL, 1, ?, ?, 0)`
  ).run(h.name, h.domains, h.upstreams, now, now);

  const id = db.query("SELECT last_insert_rowid() as id").get().id;
  console.log("INSERTED:", h.name, "id=" + id, h.domains, "->", h.upstreams);
}

console.log("\nAll proxy_hosts in DB:");
const final = db.query("SELECT id, name, domains, upstreams, enabled FROM proxy_hosts").all();
for (const r of final) {
  console.log("  -", r.name, "(id=" + r.id + ")", r.domains, "->", r.upstreams, r.enabled ? "" : "[DISABLED]");
}
