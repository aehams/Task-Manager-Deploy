const express = require('express');
const path = require('path');

const app = express();

app.use(express.static(path.join(__dirname, 'public')));

app.get('/config', (req, res) => {
    // Return the backend URL based on environment
    // When BACKEND_URL is set (from ConfigMap), use it as-is
    // Otherwise default to relative /api path
    const backendUrl = process.env.BACKEND_URL || '/api';
    res.json({
        backendUrl: backendUrl
    });
});

app.get('/health', (req, res) => {
    res.status(200).send('Frontend is healthy');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Frontend server running on port ${PORT}`);
});