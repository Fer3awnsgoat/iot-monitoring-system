// Load environment variables
require('dotenv').config();
global.mqttClient = null

const mqtt = require('mqtt');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');

// Import routes and models
const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const sensorRoutes = require('./routes/sensor.routes');
const Capteur = require('./models/Capteur');


// Initialize MQTT client outside the MongoDB connection
let mqttClient;

  // ===== ADD THIS HEALTH ENDPOINT =====
  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'healthy',
      services: {
        database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
        mqtt: mqttClient && mqttClient.connected ? 'connected' : 'disconnected'
      },
      timestamp: new Date().toISOString()
    });
  });

  // Middleware
  app.use(cors());
  app.use(bodyParser.json());

    // Routes
  app.use('/auth', authRoutes);
  app.use('/admin', adminRoutes);
  app.use('/sensors', sensorRoutes);


// Connect to MongoDB - REMOVED SPACE BEFORE CONNECTION STRING
mongoose.connect(process.env.MONGODB_URI || "mongodb+srv://kaabachi1990:PFE0123@cluster0.xxxxx.mongodb.net/myDatabase", {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
})
.then(() => {
  console.log("MongoDB connected successfully");
  
  // Initialize MQTT client
  global.mqttClient = mqtt.connect(process.env.MQTT_BROKER, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    port: 8883
  });

  mqttClient.on('connect', () => {
    console.log('Connected to MQTT broker');
    mqttClient.subscribe('esp32/sensors');
  });

  mqttClient.on('error', (err) => {
    console.error('MQTT connection error:', err);
  });

  // Initialize Express app
  const app = express();
  const port = process.env.PORT || 3001;


  // Test endpoint
  app.get('/test', (req, res) => {
    res.json({ 
      status: 'ok',
      message: 'Server is running and accessible',
      timestamp: new Date().toISOString()
    });
  });

  // 404 Handler
  app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
  });

  // Error handling middleware
  app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Internal server error' });
  });

  // Start server
  const server = app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on port ${port}`);
  });

  // Graceful shutdown
  const shutdown = () => {
    console.log('Shutting down gracefully...');
    mqttClient.end();
    server.close(() => {
      mongoose.connection.close(false, () => {
        console.log('Server stopped');
        process.exit(0);
      });
    });
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
})
.catch(err => {
  console.error('MongoDB connection error:', err);
  process.exit(1);
});