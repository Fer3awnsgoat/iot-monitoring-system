// Load environment variables
require('dotenv').config();

// Import required modules
const mqtt = require('mqtt');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');

// Import routes
const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const sensorRoutes = require('./routes/sensor.routes');

// Import models
const Capteur = require('./models/Capteur');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/iot-monitoring', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => {
  console.log("MongoDB connected successfully");
  
  // Initialize MQTT client
  const mqttClient = mqtt.connect(process.env.MQTT_BROKER, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    port: 8883
  });

  mqttClient.on('connect', () => {
    console.log('Connected to MQTT broker');
    mqttClient.subscribe('esp32/sensors');
  });

  mqttClient.on('message', async (topic, message) => {
    try {
      const data = JSON.parse(message.toString());
      const newCapteur = new Capteur(data);
      await newCapteur.save();
    } catch (err) {
      console.error('MQTT processing error:', err);
    }
  });

  // Initialize Express app
  const app = express();
  const port = process.env.PORT || 3001;

  // Middleware
  app.use(cors());
  app.use(bodyParser.json());

  // Routes
  app.use('/auth', authRoutes);
  app.use('/admin', adminRoutes);
  app.use('/sensors', sensorRoutes);

  // Test endpoint
  app.get('/test', (req, res) => {
    res.json({ 
      status: 'ok',
      message: 'Server is running and accessible',
      timestamp: new Date().toISOString()
    });
  });

  // Error handling middleware
  app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something broke!' });
  });

  // Start server
  const server = app.listen(port, '0.0.0.0', () => {
    console.log('Server running on port' + port);
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    server.close(() => {
      console.log('HTTP server closed');
      mongoose.connection.close(false, () => {
        console.log('MongoDB connection closed');
        process.exit(0);
      });
    });
  });
})
.catch(err => {
  console.error('MongoDB connection error:', err);
  process.exit(1);
});