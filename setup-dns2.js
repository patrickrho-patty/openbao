// Set up Cloudflare DNS provider in CPM's settings.
// Read the API token from stdin to avoid file permission issues.
import { Database } from "bun:sqlite";
import { hkdfSync, createCipheriv, randomBytes } from "node:crypto";

const PREFIX = "enc:v1:";
const IV_LENGTH = 12;

function deriveKey(sessionSecret) {
  return Buffer.from(
    hkdfSync("sha256", sessionSecret, Buffer.alloc(0), "caddy-proxy-manager:secret:v1", 32)
  );
}

function encryptSecret(value, sessionSecret) {
  if (!value) return "";
  if (value.startsWith(PREFIX)) return value;
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv("aes-256-gcm", deriveKey(sessionSecret), iv);
  const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${PREFIX}${iv.toString("base64")}:${tag.toString("base64")}:${ciphertext.toString("base64")}`;
}

const sessionSecret = process.env.SESSION_SECRET;
if (!sessionSecret) { console.log("ERROR: SESSION_SECRET not set"); process.exit(1); }

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const apiToken = Buffer.concat(chunks).toString("utf8").trim();
if (!apiToken) { console.log("ERROR: empty token from stdin"); process.exit(1); }

console.log("Got token, length:", apiToken.length);
const encrypted = encryptSecret(apiToken, sessionSecret);
console.log("Encrypted (first 30 chars):", encrypted.slice(0, 30) + "...");

const db = new Database("/data/caddy-proxy-manager.db");
const now = new Date().toISOString();

const value = JSON.stringify({
  providers: { cloudflare: { api_token: encrypted } },
  default: "cloudflare",
});

const existing = db.query("SELECT key FROM settings WHERE key = ?").get("dns_provider");
if (existing) {
  db.query("UPDATE settings SET value = ?, updatedAt = ? WHERE key = ?")
    .run(value, now, "dns_provider");
  console.log("UPDATED existing dns_provider setting");
} else {
  db.query("INSERT INTO settings (key, value, updatedAt) VALUES (?, ?, ?)")
    .run("dns_provider", value, now);
  console.log("INSERTED new dns_provider setting");
}
console.log("Done. Restart CPM to apply.");
