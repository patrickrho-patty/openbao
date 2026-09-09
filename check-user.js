import { Database } from "bun:sqlite";
const db = new Database("/data/caddy-proxy-manager.db", { readonly: true });
const users = db.query("SELECT id, email, name, username, displayUsername, role, provider FROM users").all();
console.log("Users:", JSON.stringify(users, null, 2));
const accounts = db.query("SELECT id, userId, providerId, accountId FROM accounts").all();
console.log("Accounts:", JSON.stringify(accounts, null, 2));
const sessions = db.query("SELECT id, userId, token, expiresAt, ipAddress FROM sessions ORDER BY createdAt DESC LIMIT 3").all();
console.log("Recent sessions:", JSON.stringify(sessions, null, 2));
