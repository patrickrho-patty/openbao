// Add secrets.patty.io proxy host + fix admin email
import { Database } from "bun:sqlite";

const db = new Database("/data/caddy-proxy-manager.db");

const now = new Date().toISOString();

// === 1. Add secrets.patty.io proxy host ===
const host = {
  name: "OpenBao Secrets Manager",
  domains: JSON.stringify(["secrets.patty.io"]),
  upstreams: JSON.stringify(["http://openbao:8200"]),
};

// Skip if already present
const all = db.query("SELECT id, name, domains FROM proxy_hosts").all();
const dup = all.find((r) => {
  try {
    return JSON.parse(r.domains).includes(JSON.parse(host.domains)[0]);
  } catch (e) {
    return false;
  }
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

// === 2. Fix admin email to a valid format (so email login works for future API use) ===
const before = db.query("SELECT email FROM users WHERE id = 1").get();
if (before.email !== "admin@patty.io") {
  db.query("UPDATE users SET email = ? WHERE id = 1").run("admin@patty.io");
  console.log("UPDATED admin email: " + before.email + " -> admin@patty.io");
} else {
  console.log("admin email already correct");
}

// Also update the accounts table (where Better Auth stores the user identifier)
const account = db.query("SELECT id, accountId FROM accounts WHERE userId = 1").get();
if (account) {
  if (account.accountId !== "admin@patty.io") {
    db.query("UPDATE accounts SET accountId = ? WHERE id = ?").run("admin@patty.io", account.id);
    console.log("UPDATED account.accountId to admin@patty.io");
  }
}

console.log("\nAll proxy_hosts in DB:");
const final = db.query("SELECT id, name, domains, upstreams, enabled FROM proxy_hosts").all();
for (const r of final) {
  console.log("  -", r.name, "(id=" + r.id + ")", r.domains, "->", r.upstreams);
}
