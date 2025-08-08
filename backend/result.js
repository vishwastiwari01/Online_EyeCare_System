const express = require('express');
const pool = require('./db');
const jwt = require('jsonwebtoken');

const router = express.Router();

// Middleware to verify JWT token and extract user ID
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (token == null) return res.sendStatus(401);

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// POST route to save a new test result
router.post('/', authenticateToken, async(req, res) => {
    const userId = req.user.id;
    const {
        left_eye_acuity,
        right_eye_acuity,
        left_eye_power,
        right_eye_power,
        left_eye_condition,
        right_eye_condition
    } = req.body;

    if (!left_eye_acuity || !right_eye_acuity) {
        return res.status(400).json({ error: 'Missing required test result fields' });
    }

    const query = `
        INSERT INTO test_results 
        (user_id, left_eye_acuity, right_eye_acuity, left_eye_power, right_eye_power, left_eye_condition, right_eye_condition) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `;

    pool.query(query, [userId, left_eye_acuity, right_eye_acuity, left_eye_power, right_eye_power, left_eye_condition, right_eye_condition], (err, result) => {
        if (err) {
            console.error('Database error while saving result:', err);
            return res.status(500).json({ error: 'Failed to save test result' });
        }
        res.status(201).json({ message: 'Test result saved successfully', resultId: result.insertId });
    });
});

// GET route to fetch all test results for the logged-in user
router.get('/', authenticateToken, (req, res) => {
    const userId = req.user.id;
    const query = 'SELECT * FROM test_results WHERE user_id = ? ORDER BY test_date DESC';

    pool.query(query, [userId], (err, results) => {
        if (err) {
            console.error('Database error while fetching results:', err);
            return res.status(500).json({ error: 'Failed to fetch test history' });
        }
        res.json(results);
    });
});

module.exports = router;