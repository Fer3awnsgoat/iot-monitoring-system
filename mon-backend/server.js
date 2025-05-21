// Debug information
console.log('Starting server with Node version:', process.version);
console.log('Current working directory:', process.cwd());
console.log('Files in directory:', require('fs').readdirSync('.'));

// Load environment variables
require('dotenv').config();

// Import required modules
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

// Initialize Express app - make sure this is BEFORE any route definitions
const app = express();
console.log('Express app initialized');
const port = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Health check endpoint
app.get('/health', (req, res) => {
  console.log('Health check endpoint hit');
  res.status(200).json({
    status: 'healthy',
    services: {
      database: mongoose.connection?.readyState === 1 ? 'connected' : 'disconnected',
      mqtt: global.mqttClient?.connected ? 'connected' : 'disconnected'
    },
    timestamp: new Date().toISOString()
  });
});

// Test endpoint
app.get('/test', (req, res) => {
  console.log('Test endpoint hit');
  res.json({ 
    status: 'ok',
    message: 'Server is running and accessible',
    timestamp: new Date().toISOString()
  });
});

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || "mongodb+srv://kaabachi1990:PFE0123@cluster0.xxxxx.mongodb.net/myDatabase", {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
})
.then(() => {
  console.log("MongoDB connected successfully");
  
  // Initialize MQTT client
  try {
    global.mqttClient = mqtt.connect(process.env.MQTT_BROKER, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    port: 1883,
});

    global.mqttClient.on('connect', () => {
      console.log('Connected to MQTT broker');
      global.mqttClient.subscribe('esp32/sensors');
    });

    global.mqttClient.on('error', (err) => {
      console.error('MQTT connection error:', err);
    });
  } catch (error) {
    console.error('Failed to connect to MQTT:', error);
  }

  // Routes
  app.use('/auth', authRoutes);
  app.use('/admin', adminRoutes);
  app.use('/sensors', sensorRoutes);

  app.get('/', (req, res) => {
  res.json({ message: 'Welcome to IoT Monitoring System API' });
  });
  // 404 Handler
  app.use((req, res) => {
    console.log('404 - Route not found:', req.path);
    res.status(404).json({ error: 'Route not found' });
  });

  // Error handling middleware
  app.use((err, req, res, next) => {
    console.error('Server error:', err.stack);
    res.status(500).json({ error: 'Internal server error' });
  });

  // Start server
  const server = app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on port ${port}`);
    console.log(`Health check endpoint available at: http://localhost:${port}/health`);
    console.log(`Test endpoint available at: http://localhost:${port}/test`);
  });

  // Graceful shutdown
  const shutdown = () => {
    console.log('Shutting down gracefully...');
    global.mqttClient?.end();
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