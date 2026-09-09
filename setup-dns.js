// Set up Cloudflare DNS provider in CPM's settings.
// We duplicate CPM's encryption (HKDF + AES-256-GCM) so the stored
// credential can be decrypted by CPM on read.
import { Database } from "bun:sqlite";
import { hkdfSync, createCipheriv, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";

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
if (!sessionSecret) {
  console.log("ERROR: SESSION_SECRET env var not set");
  process.exit(1);
}

const tokenPath = process.argv[2];
if (!tokenPath) {
  console.log("Usage: bun setup-dns.js <cloudflare-token-file>");
  process.exit(1);
}

const apiToken = readFileSync(tokenPath, "utf8").trim();
if (!apiToken) {
  console.log("ERROR: empty token file");
  process.exit(1);
}

console.log("Encrypting Cloudflare API token...");
const encrypted = encryptSecret(apiToken, sessionSecret);
console.log("Encrypted token (first 30 chars):", encrypted.slice(0, 30) + "...");

const db = new Database("/data/caddy-proxy-manager.db");
const now = new Date().toISOString();

// DnsProviderSettings shape:
// { providers: { cloudflare: { api_token: "<encrypted>" } }, default: "cloudflare" }
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

console.log("\nDone. Restart CPM to pick up the new DNS provider config.");
