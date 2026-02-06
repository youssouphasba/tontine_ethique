const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // I might not have this, searching for alternative

// Try to use environment default or internal config if possible
// But wait, I can just use the functions directory which already has admin setup
