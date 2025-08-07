// auth.js
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('./db'); // Import the connection pool

const router = express.Router();

// Register route
router.post('/register', async(req, res) => {
    console.log('Received registration request. Body:', req.body);

    const { email, password, name } = req.body;

    if (!email || !password || !name) {
        console.error('Validation error: Missing email, password, or name in request.');
        return res.status(400).json({ error: 'Missing required fields (email, password, name)' });
    }

    try {
        const hashed = await bcrypt.hash(password, 10);
        console.log('Password hashed successfully.');

        const role = 'user';

        // Use pool.query instead of db.query
        pool.query(
            'INSERT INTO users (email, password, name, role) VALUES (?, ?, ?, ?)', [email, hashed, name, role],
            (err, result) => {
                if (err) {
                    console.error('Database error during registration (SQL Query Error):', err);
                    if (err.code === 'ER_DUP_ENTRY') {
                        return res.status(409).json({ error: 'Email already registered' });
                    }
                    return res.status(500).json({ error: 'Database error during registration' });
                }
                console.log('User inserted into database successfully. Result:', result);
                res.status(201).json({ message: 'User registered successfully' });
            }
        );
    } catch (e) {
        console.error('Server error during registration (Try-Catch Block Error):', e);
        return res.status(500).json({ error: 'Internal server error during registration' });
    }
});

// Login route
router.post('/login', async(req, res) => {
    console.log('Received login request. Body:', req.body);
    const { email, password } = req.body;

    if (!email || !password) {
        console.error('Validation error: Missing email or password for login.');
        return res.status(400).json({ error: 'Missing required fields (email, password)' });
    }

    // Use pool.query instead of db.query
    pool.query('SELECT id, email, password, name, role FROM users WHERE email = ?', [email], async(err, results) => {
        if (err) {
            console.error('Database error during login (SQL Query Error):', err);
            return res.status(500).json({ error: 'Database error during login' });
        }
        if (results.length === 0) {
            console.log('Login failed: User not found for email:', email);
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        const user = results[0];
        console.log('User found:', user.email);

        try {
            const match = await bcrypt.compare(password, user.password);
            if (!match) {
                console.log('Login failed: Incorrect password for email:', email);
                return res.status(401).json({ error: 'Invalid email or password' });
            }

            const token = jwt.sign({ id: user.id, role: user.role, email: user.email }, process.env.JWT_SECRET, { expiresIn: '1h' });
            console.log('User logged in successfully. Token generated.');

            res.json({
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    role: user.role
                }
            });
        } catch (e) {
            console.error('Server error during login (Try-Catch Block Error):', e);
            return res.status(500).json({ error: 'Internal server error during login' });
        }
    });
});

module.exports = router;