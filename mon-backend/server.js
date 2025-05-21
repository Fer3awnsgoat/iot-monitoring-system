// Load environment variables
require('dotenv').config();
console.log('Environment variables loaded from .env');


// Debug information
console.log('=== Server Startup ===');
console.log('Starting server with Node version:', process.version);
console.log('Current working directory:', process.cwd());
console.log('Files in directory:', require('fs').readdirSync('.'));
console.log('Environment variables loaded:', {
  MQTT_BROKER: process.env.MQTT_BROKER ? 'Set' : 'Not set',
  MQTT_USERNAME: process.env.MQTT_USERNAME ? 'Set' : 'Not set',
  MONGODB_URI: process.env.MONGODB_URI ? 'Set' : 'Not set',
  SMTP_HOST: process.env.SMTP_HOST ? 'Set' : 'Not set',
  PORT: process.env.PORT || 3001
});



// Import required modules
console.log('Importing required modules...');
const mqtt = require('mqtt');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
console.log('All modules imported successfully');

// Import routes and models
console.log('Importing routes and models...');
const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const sensorRoutes = require('./routes/sensor.routes');
const Capteur = require('./models/Capteur');
const Notification = require('./models/Notification');
const User = require('./models/User');
const Threshold = require('./models/Threshold');
const { sendEmail } = require('./utils/email');
console.log('Routes and models imported successfully');

// Initialize Express app
const app = express();
console.log('Express app initialized');
const port = process.env.PORT || 3001;

// Middleware
console.log('Setting up middleware...');
app.use(cors());
app.use(bodyParser.json());
console.log('Middleware setup complete');

// Routes
console.log('Setting up routes...');
app.use('/auth', authRoutes);
app.use('/admin', adminRoutes);
app.use('/sensors', sensorRoutes);
console.log('Routes setup complete');

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

// Initialize MQTT client
const initializeMQTT = () => {
  try {
    console.log('=== MQTT Initialization ===');
    console.log('Connecting to MQTT broker at:', process.env.MQTT_BROKER);
    console.log('Using username:', process.env.MQTT_USERNAME);

    const options = {
      username: process.env.MQTT_USERNAME,
      password: process.env.MQTT_PASSWORD,
    };

    global.mqttClient = mqtt.connect(process.env.MQTT_BROKER, options);
    console.log('MQTT client created');

    global.mqttClient.on('connect', () => {
      console.log('Connected to MQTT broker');
      global.mqttClient.subscribe('esp32/sensors', (err) => {
        if (err) {
          console.error('Subscription error:', err);
        } else {
          console.log('Subscribed to esp32/sensors');
        }
      });
    });

    global.mqttClient.on('message', async (topic, message) => {
      try {
        if (topic === 'esp32/sensors') {
          console.log('=== MQTT Message Received ===');
          console.log('Topic:', topic);
          console.log('Raw message:', message.toString());
          
          const payload = JSON.parse(message.toString());
          console.log('Parsed payload:', payload);

          // Check if this is a pre-formatted notification or raw sensor data
          if (payload.type && payload.status && payload.message) {
            console.log('Processing pre-formatted notification');
            await handlePreformattedNotification(payload);
          } else {
            console.log('Processing raw sensor data');
            await handleRawSensorData(payload);
          }
        }
      } catch (error) {
        console.error('Error processing MQTT message:', error);
        console.error('Message content:', message.toString());
      }
    });

    global.mqttClient.on('error', (err) => {
      console.error('MQTT connection error:', err);
    });

    global.mqttClient.on('close', () => {
      console.log('MQTT connection closed');
    });

    global.mqttClient.on('offline', () => {
      console.log('MQTT client offline');
    });

    global.mqttClient.on('reconnect', () => {
      console.log('MQTT client reconnecting');
    });
  } catch (error) {
    console.error('Failed to connect to MQTT:', error);
  }
};

// Helper function to determine notification status based on value and thresholds
const getNotificationStatus = (type, value, thresholds) => {
  if (!thresholds) return 'normal'; // Default to normal if thresholds not loaded

  switch (type) {
    case 'gas':
      if (value >= thresholds.gasDangerThreshold) return 'dangerous';
      if (value >= thresholds.gasWarningThreshold) return 'warning';
      break;
    case 'temperature':
      if (value >= thresholds.tempDangerThreshold) return 'dangerous';
      if (value >= thresholds.tempWarningThreshold) return 'warning';
      break;
    case 'sound':
      if (value >= thresholds.soundDangerThreshold) return 'dangerous';
      if (value >= thresholds.soundWarningThreshold) return 'warning';
      break;
  }
  return 'normal';
};

// Process pre-formatted notifications
const handlePreformattedNotification = async (payload) => {
  try {
    const adminUser = await User.findOne({ isAdmin: true });
    
    if (!adminUser) {
      console.warn('No admin user found for notification');
      return;
    }

    const notification = new Notification({
      type: payload.type,
      status: payload.status,
      message: payload.message,
      value: payload.value,
      timestamp: new Date(),
      user: adminUser._id
    });

    await notification.save();
    console.log('Notification saved:', notification);

    // Send email if the user is subscribed
    if (adminUser.email) {
      const emailSubject = `Alert: ${payload.type.toUpperCase()} ${payload.status.toUpperCase()}`;
      const emailHtml = `
        <div style="padding: 20px; background-color: ${payload.status === 'dangerous' ? '#ffebee' : '#fff3e0'};">
          <h2>Sensor Alert</h2>
          <p><strong>Type:</strong> ${payload.type}</p>
          <p><strong>Status:</strong> ${payload.status}</p>
          <p><strong>Value:</strong> ${payload.value}${payload.type === 'temperature' ? '°C' : payload.type === 'gas' ? 'ppm' : 'dB'}</p>
          <p><strong>Message:</strong> ${payload.message}</p>
          <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
        </div>
      `;

      if (typeof sendEmail === 'function') {
        await sendEmail({
          to: adminUser.email,
          subject: emailSubject,
          html: emailHtml
        });
        console.log(`Email sent for ${payload.type} alert to ${adminUser.email}`);
      }
    }
  } catch (error) {
    console.error('Error handling pre-formatted notification:', error);
  }
};

// Process raw sensor data
const handleRawSensorData = async (rawPayload) => {
  try {
    let thresholds = await Threshold.findOne().sort({ createdAt: -1 });
    if (!thresholds) {
      console.warn('Thresholds not found when processing MQTT message, using default normal status.');
      thresholds = {
        gasThreshold: 0, tempThreshold: 0, soundThreshold: 0,
        gasWarningThreshold: 100, tempWarningThreshold: 30, soundWarningThreshold: 80,
        gasDangerThreshold: 200, tempDangerThreshold: 40, soundDangerThreshold: 100
      };
    }

    // Process each sensor type in the payload
    for (const sensorType in rawPayload) {
      if (rawPayload.hasOwnProperty(sensorType)) {
        const value = rawPayload[sensorType];
        const type = sensorType.toLowerCase();

        // Determine status based on thresholds
        const status = getNotificationStatus(type, value, thresholds);

        // Save Capteur data
        const capteurData = new Capteur({
          [type]: value,
          timestamp: new Date()
        });
        await capteurData.save();
        console.log('Sensor data saved to MongoDB:', { type, value, timestamp: capteurData.timestamp });

        // Process notifications for warning or dangerous statuses
        if (status === 'warning' || status === 'dangerous') {
          await createSensorAlertNotification(type, status, value, thresholds);
        }
      }
    }
  } catch (error) {
    console.error('Error handling raw sensor data:', error);
  }
};

// Create sensor alert notification
const createSensorAlertNotification = async (type, status, value, thresholds) => {
  try {
    const adminUser = await User.findOne({ isAdmin: true });

    if (!adminUser) {
      console.warn('No admin user found for sensor alert');
      return;
    }

    const notification = new Notification({
      type: type,
      status: status,
      message: `Sensor ${type} alert: value ${value}`,
      value: value,
      timestamp: new Date(),
      user: adminUser._id
    });

    await notification.save();
    console.log('Notification saved:', notification);

    if (adminUser.email) {
      const emailSubject = `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`;
      const emailHtml = `
        <div style="padding: 20px; background-color: ${status === 'dangerous' ? '#ffebee' : '#fff3e0'};">
          <h2>Sensor Alert</h2>
          <p><strong>Type:</strong> ${type}</p>
          <p><strong>Status:</strong> ${status} (${type === 'temperature' ? 
            `Threshold: ${status === 'warning' ? thresholds.tempWarningThreshold : thresholds.tempDangerThreshold}°C` : 
            `Threshold: ${status === 'warning' ? thresholds[`${type}WarningThreshold`] : thresholds[`${type}DangerThreshold`]}${type === 'gas' ? 'ppm' : 'dB'}`})</p>
          <p><strong>Value:</strong> ${value}${type === 'temperature' ? '°C' : type === 'gas' ? 'ppm' : 'dB'}</p>
          <p><strong>Message:</strong> ${type.charAt(0).toUpperCase() + type.slice(1)} is ${status === 'dangerous' ? 'critically high' : 'high'}</p>
          <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
        </div>
      `;

      if (typeof sendEmail === 'function') {
        await sendEmail({
          to: adminUser.email,
          subject: emailSubject,
          html: emailHtml
        });
        console.log(`Email sent for ${type} alert to ${adminUser.email}`);
      }
    }
  } catch (error) {
    console.error('Error creating sensor alert notification:', error);
  }
};

// Connect to MongoDB
console.log('=== MongoDB Connection ===');
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
})
.then(() => {
  console.log("MongoDB connected successfully");
  
  // Initialize MQTT after DB connection
  console.log('Initializing MQTT...');
  initializeMQTT();

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
    console.log('=== Server Started ===');
    console.log(`Server running on port ${port}`);
  });

  // Graceful shutdown
  const shutdown = () => {
    console.log('=== Server Shutdown ===');
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
  console.error('=== MongoDB Connection Error ===');
  console.error('MongoDB connection error:', err);
  process.exit(1);
});