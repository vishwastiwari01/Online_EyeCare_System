const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Import routes
const authRoutes = require('./auth');
const resultsRoutes = require('./results');

// Use routes
app.use('/api/auth', authRoutes);
app.use('/api/results', resultsRoutes);

app.listen(process.env.PORT, () => {
    console.log(`🚀 Server running on port ${process.env.PORT}`);
});