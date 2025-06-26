const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json()); // This line is crucial for parsing JSON request bodies

const authRoutes = require('./auth');
app.use('/api/auth', authRoutes);

app.listen(process.env.PORT, () => {
    console.log(`🚀 Server running on port ${process.env.PORT}`);
});