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

// Read credentials from JSON file
const credentialsFile = process.argv[2] || 'decrypted_credentials.json';
const credentials = JSON.parse(fs.readFileSync(credentialsFile, 'utf8'));

// Create SQL statements for each credential
let sqlStatements = [];
credentials.forEach(cred => {
    const encryptedData = encryptData(cred.data);
    const sql = `INSERT INTO credentials_entity (name, type, data, createdAt, updatedAt) VALUES ('${cred.name}', '${cred.type}', '${encryptedData}', '${cred.createdAt}', '${cred.updatedAt}');`;
    sqlStatements.push(sql);
});

// Write SQL to file
fs.writeFileSync('all_credentials.sql', sqlStatements.join('\n'));
console.log('SQL file generated: all_credentials.sql');
