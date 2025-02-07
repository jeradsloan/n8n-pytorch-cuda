const crypto = require('crypto');
const fs = require('fs');

// Read the encryption key from environment variable or config file
const ENCRYPTION_KEY = 'CsNOkmHfquyZck+JLYa0Yie7GKZKW7VI';

// Function to derive key and IV using n8n's method
function getKeyAndIv(salt) {
    const key = crypto.createHash('md5').update(ENCRYPTION_KEY + salt).digest();
    const iv = crypto.createHash('md5').update(key + ENCRYPTION_KEY + salt).digest().subarray(0, 16);
    return [key, iv];
}

// Function to encrypt data using n8n's format
function encryptCredential(data) {
    const salt = crypto.randomBytes(8);
    const [key, iv] = getKeyAndIv(salt);
    const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
    let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'base64');
    encrypted += cipher.final('base64');
    return `${salt.toString('base64')}:${encrypted}`;
}

// Example credential data
const credentialData = {
    name: process.argv[2] || 'Test Credential',
    type: process.argv[3] || 'oauthApi',
    data: JSON.parse(process.argv[4] || '{"token": "test-token"}')
};

// Encrypt the credential
const encryptedData = encryptCredential(credentialData.data);

// Generate SQL
const sql = `INSERT INTO credentials_entity (name, type, data, createdAt, updatedAt) 
VALUES ('${credentialData.name}', '${credentialData.type}', '${encryptedData}', 
datetime('now'), datetime('now'));`;

// Write SQL to file
fs.writeFileSync('single_credential.sql', sql);
console.log('SQL file generated: single_credential.sql');
