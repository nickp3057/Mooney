// Single-user, single-item persistence for the Plaid access_token. Encrypted
// at rest (AES-256-GCM, key from TOKEN_ENCRYPTION_KEY) so the token isn't
// sitting in plaintext on disk — the file itself already never leaves the
// NAS since it's gitignored and the server is Tailscale-only, but this adds
// a second layer in case the volume/backup is ever exposed.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DATA_DIR = path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'item.json');

function getKey() {
  const hex = process.env.TOKEN_ENCRYPTION_KEY;
  if (!hex || hex.length !== 64) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be a 64-character hex string (32 bytes) — generate one with `openssl rand -hex 32`');
  }
  return Buffer.from(hex, 'hex');
}

function encrypt(plaintext) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return {
    iv: iv.toString('hex'),
    authTag: authTag.toString('hex'),
    ciphertext: ciphertext.toString('hex'),
  };
}

function decrypt({ iv, authTag, ciphertext }) {
  const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), Buffer.from(iv, 'hex'));
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(ciphertext, 'hex')),
    decipher.final(),
  ]);
  return plaintext.toString('utf8');
}

function saveItem({ accessToken, accountId }) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const record = {
    accessToken: encrypt(accessToken),
    accountId,
  };
  fs.writeFileSync(DATA_FILE, JSON.stringify(record), { mode: 0o600 });
}

function loadItem() {
  if (!fs.existsSync(DATA_FILE)) return null;
  const record = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  return {
    accessToken: decrypt(record.accessToken),
    accountId: record.accountId,
  };
}

function clearItem() {
  if (fs.existsSync(DATA_FILE)) fs.unlinkSync(DATA_FILE);
}

module.exports = { saveItem, loadItem, clearItem, DATA_FILE };
