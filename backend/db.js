// db.js
const mysql = require('mysql2');
require('dotenv').config();

// Create a connection pool instead of a single connection
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT,
    ssl: {
        // an empty object is enough to enable SSL/TLS
    },
    waitForConnections: true, // If true, pool will queue requests when no connection is available
    connectionLimit: 10, // Max number of connections in the pool
    queueLimit: 0 // Unlimited queueing for connections
});

// Test the connection pool (optional, but good for initial setup)
pool.getConnection((err, connection) => {
    if (err) {
        console.error('❌ Error connecting to database pool:', err);
        // Depending on the error, you might want to exit the process or retry
        if (err.code === 'PROTOCOL_CONNECTION_LOST') {
            console.error('Database connection was closed.');
        } else if (err.code === 'ER_CON_COUNT_ERROR') {
            console.error('Database has too many connections.');
        } else if (err.code === 'ECONNREFUSED') {
            console.error('Database connection refused. Check host, port, and firewall.');
        } else {
            console.error('Unhandled database connection error:', err.code);
        }
        return; // Don't throw, just log
    }
    console.log("✅ MySQL Pool Connected");
    connection.release(); // Release the connection back to the pool
});

module.exports = pool; // Export the pool instead of the single connection