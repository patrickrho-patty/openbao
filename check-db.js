import { Database } from "bun:sqlite";
const db = new Database("/data/caddy-proxy-manager.db", { readonly: true });
const tables = db.query("SELECT name FROM sqlite_master WHERE type='table'").all();
console.log("Tables:", tables.map(t => t.name).join(", "));
for (const t of tables) {
  console.log("\n--- Table:", t.name, "---");
  try {
    const cols = db.query("PRAGMA table_info('" + t.name + "')").all();
    console.log("Columns:", cols.map(c => c.name).join(", "));
  } catch(e) {}
}
