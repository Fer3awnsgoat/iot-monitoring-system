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
const Notification = require('./models/Notification');
const User = require('./models/User');
const Threshold = require('./models/Threshold');
const { sendEmail } = require('./utils/email');

// Initialize Express app - make sure this is BEFORE any route definitions
const app = express();
console.log('Express app initialized');
const port = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Routes
app.use('/auth', authRoutes);
app.use('/admin', adminRoutes);
app.use('/sensors', sensorRoutes);

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
try {
  console.log('Connecting to MQTT broker at:', process.env.MQTT_BROKER);
  console.log('Using username:', process.env.MQTT_USERNAME);

  const options = {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
  };

  global.mqttClient = mqtt.connect(process.env.MQTT_BROKER, options);

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
        console.log('Received MQTT message:', message.toString());
        
        const rawPayload = JSON.parse(message.toString());
        
        // Fetch the latest thresholds once per message batch if processing multiple sensors
        let thresholds = await Threshold.findOne().sort({ createdAt: -1 });
        if (!thresholds) {
          console.warn('Thresholds not found when processing MQTT message, using default normal status.');
          thresholds = { // Use safe defaults or handle appropriately
            gasThreshold: 0, tempThreshold: 0, soundThreshold: 0,
            gasWarningThreshold: 100, tempWarningThreshold: 30, soundWarningThreshold: 80, // Example warning defaults
            gasDangerThreshold: 200, tempDangerThreshold: 40, soundDangerThreshold: 100 // Example danger defaults
          };
        }

        // Process each sensor type in the payload
        for (const sensorType in rawPayload) {
          if (rawPayload.hasOwnProperty(sensorType)) {
            const value = rawPayload[sensorType];
            const type = sensorType.toLowerCase(); // Ensure type is lowercase

            // Determine status based on thresholds
            const status = getNotificationStatus(type, value, thresholds);

            // Save Capteur data for ALL sensor readings
            const capteurData = new Capteur({
              [type]: value, // Use computed type
              timestamp: new Date()
              // You might need to add a field to link this Capteur data to a specific device/location
            });
            await capteurData.save();
            console.log('Sensor data saved to MongoDB:', { type, value, timestamp: capteurData.timestamp });

            // ONLY save and process notifications for warning or dangerous statuses
            if (status === 'warning' || status === 'dangerous') {
              // Fetch the user associated with this sensor data (you'll need a way to map sensors to users)
              // For this example, we'll assume a default admin user for now, or you need to implement user association logic
              const adminUser = await User.findOne({ isAdmin: true }); // Example: find an admin user

              if (adminUser) {
                const notification = new Notification({
                  type: type,
                  status: status,
                  message: `Sensor ${type} alert: value ${value}`,
                  value: value,
                  timestamp: new Date(),
                  user: adminUser._id // Assign to the found admin user
                });

                await notification.save();
                console.log('Notification saved:', notification);

                // Send email if the user is subscribed and status is warning/dangerous
                // (Assuming user model has an email field and a subscription preference if needed)
                if (adminUser.email) { // You might add a user preference check here too
                  // Note: The sendEmail function is in utils/email.js and should be imported.
                  // We need the message and subject structure to match what sendEmail expects.
                  // Let's format it similar to the frontend's POST route.

                  const emailSubject = `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`;
                  const emailHtml = `
                    <div style="padding: 20px; background-color: ${status === 'dangerous' ? '#ffebee' : '#fff3e0'};">
                      <h2>Sensor Alert</h2>
                      <p><strong>Type:</strong> ${type}</p>
                      <p><strong>Status:</strong> ${status}</p>
                      <p><strong>Value:</strong> ${value}</p>
                      <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
                    </div>
                  `;

                  // Check if sendEmail function is available (imported at the top)
                  if (typeof sendEmail === 'function') {
                    await sendEmail({
                      to: adminUser.email,
                      subject: emailSubject,
                      html: emailHtml
                    });
                    console.log(`Email sent for ${type} alert to ${adminUser.email}`);
                  } else {
                    console.error('sendEmail function not available.');
                  }
                } else {
                  console.warn(`Admin user found but no email address for sending alerts.`);
                }
              } else {
                console.warn('Admin user not found. Cannot create notification or send email.');
              }
            }
          }
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

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || "mongodb+srv://kaabachi1990:PFE0123@cluster0.xxxxx.mongodb.net/myDatabase", {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
})
.then(() => {
  console.log("MongoDB connected successfully");

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

// Function to process incoming sensor data and create notifications/alerts
const processSensorData = async (payload) => {
  // ... existing code ...

  // Determine status based on thresholds (you'll need to fetch thresholds here)
  let thresholds = await Threshold.findOne().sort({ createdAt: -1 });
  if (!thresholds) {
      // Handle case where thresholds aren't set, maybe log a warning or use defaults
      console.warn('Thresholds not found, using default normal status.');
      thresholds = { // Use safe defaults or handle appropriately
          gasThreshold: 0, tempThreshold: 0, soundThreshold: 0,
          gasWarningThreshold: 100, tempWarningThreshold: 30, soundWarningThreshold: 80, // Example warning defaults
          gasDangerThreshold: 200, tempDangerThreshold: 40, soundDangerThreshold: 100 // Example danger defaults
      };
  }

  const status = getNotificationStatus(
      payload.type, // Assuming payload includes a type field (e.g., 'gas', 'temperature', 'sound')
      payload.value, // Assuming payload includes a value field
      thresholds
  );

  // ONLY save and process notifications for warning or dangerous statuses
  if (status === 'warning' || status === 'dangerous') {
    const notification = new Notification({
      type: payload.type, // Use type from payload
      status: status,
      message: `Sensor ${payload.type} alert: value ${payload.value}`,
      value: payload.value,
      timestamp: new Date(),
      // Assuming user is associated with the sensor data or inferred otherwise
      // For simplicity, you might need to associate sensor data with users based on device/config
      // For now, let's assume a default user or fetch based on device ID if available in payload
      // user: userId // You need to determine the user ID here
    });

    await notification.save();
    console.log('Notification saved:', notification);

    // Send email if user is subscribed and status is warning/dangerous (logic already exists in sensor.routes)
    // The email sending logic is currently in the POST /notifications route, which is triggered by the frontend.
    // If you want emails to be sent automatically by the backend upon receiving MQTT data,
    // you need to move the email sending logic here and associate the sensor data with a user.
    // For now, let's keep email sending tied to the frontend's POST /notifications call.
  }
};