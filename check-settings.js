// Check the settings table to see what's there
import { Database } from "bun:sqlite";
const db = new Database("/data/caddy-proxy-manager.db", { readonly: true });
const rows = db.query("SELECT * FROM settings").all();
for (const r of rows) {
  console.log(r.key, "=", r.value);
}
