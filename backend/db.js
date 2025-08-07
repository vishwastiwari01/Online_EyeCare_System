const mysql = require('mysql2');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Create a connection pool instead of a single connection
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT,
    ssl: {
        // Corrected to use your actual certificate file name
        ca: fs.readFileSync(path.join(__dirname, 'isrgrootx1.pem'))
    },
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Test the connection pool
pool.getConnection((err, connection) => {
    if (err) {
        console.error('❌ Error connecting to database pool:', err);
        return;
    }
    console.log("✅ MySQL Pool Connected");
    connection.release();
});

module.exports = pool;