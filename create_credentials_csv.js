const fs = require('fs');
const crypto = require('crypto');

// Read credentials from JSON file
const credentialsFile = process.argv[2] || 'decrypted_credentials.json';
const credentials = JSON.parse(fs.readFileSync(credentialsFile, 'utf8'));

// Convert credentials to CSV format
let csvRows = ['Name,Type,Data'];

credentials.forEach(cred => {
    const name = cred.name.replace(/,/g, '_');
    const type = cred.type;
    const data = JSON.stringify(cred.data).replace(/,/g, ';');
    csvRows.push(`${name},${type},${data}`);
});

// Write to CSV file
fs.writeFileSync('credentials.csv', csvRows.join('\n'));
console.log('CSV file generated: credentials.csv');
