const mqtt = require('mqtt');
// Connexion au broker MQTT (ici un exemple public, tu peux utiliser Mosquitto ou HiveMQ)
const mqttClient = mqtt.connect('mqtts://7acbf0113cb946a0a2d2f4a344294183.s1.eu.hivemq.cloud', {
  username: 'AMpfe',
  password: 'AhmedAmine0123'
});
mqttClient.on('connect', () => {
  console.log(' Connecté au broker MQTT');

  // S'abonner au topic où l'ESP32 publie les données
  mqttClient.subscribe('esp32/sensors', (err) => {
    if (err) {
      console.error(' Erreur lors de l\'abonnement au topic MQTT');
    }
  });
});

// Quand un message est reçu sur le topic
mqttClient.on('message', async (topic, message) => {
  try {
    const data = JSON.parse(message.toString());
    console.log(' Données MQTT reçues :', data);

    const newCapteur = new Capteur(data);
    await newCapteur.save();
    console.log(' Données sauvegardées dans MongoDB');
  } catch (err) {
    console.error(' Erreur traitement MQTT :', err);
  }
});
const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const Capteur = require('./models/Capteur'); // Importer le modèle
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken'); // Add JWT
const cors = require('cors');
const Threshold = require('./models/Threshold'); // Import Threshold model
const PendingUser = require('./models/PendingUser'); // Import PendingUser model
const nodemailer = require('nodemailer');

const app = express();
const port = 3001;

// JWT Secret Key
const JWT_SECRET = 'your-secret-key'; // Change this to a secure secret key in production

// Use CORS middleware
app.use(cors());


// Middleware
app.use(bodyParser.json());

// Connexion à MongoDB
mongoose.connect('mongodb+srv://kaabachi1990:PFE0123@cluster0.3cqqv.mongodb.net/mon-backend?retryWrites=true&w=majority')
  .then(() => {
    console.log(" MongoDB connecté");
  })
  .catch((err) => {
    console.error(" Erreur de connexion à MongoDB :", err);
  });

  const User = require('./models/User');
  
  // Modified Registration endpoint - now creates pending registration instead
  app.post('/register', async (req, res) => {
    const { username, email, password } = req.body;
  
    try {
      // Check if user already exists in Users or PendingUsers
      const existingUser = await User.findOne({ 
        $or: [{ username }, { email }]
      });
  
      if (existingUser) {
        return res.status(400).json({ 
          error: existingUser.username === username 
            ? 'Username already exists' 
            : 'Email already exists'
        });
      }
  
      const existingPendingUser = await PendingUser.findOne({
        $or: [{ username }, { email }],
        status: 'pending'
      });
  
      if (existingPendingUser) {
        return res.status(400).json({ 
          error: existingPendingUser.username === username 
            ? 'Username already has a pending request' 
            : 'Email already has a pending request'
        });
      }
  
      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);
  
      // Create pending user request
      const pendingUser = new PendingUser({
        username,
        email,
        password: hashedPassword,
        status: 'pending'
      });
  
      await pendingUser.save();
  
      res.status(201).json({
        message: 'Registration request submitted. Waiting for admin approval.',
        pending: true
      });
    } catch (err) {
      console.error(' Registration request error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });  
  // ======================
app.post('/data', async (req, res) => {
  const data = req.body;
  console.log(' Données reçues :', data);

  try {
    // Crée un nouvel objet Capteur à partir des données reçues
    const newCapteur = new Capteur(data);

    // Sauvegarde dans MongoDB
    await newCapteur.save();

    res.status(200).json({ message: 'Données enregistrées avec succès !', data: newCapteur });
  } catch (err) {
    console.error('❌ Erreur lors de l\'enregistrement des données :', err);
    res.status(500).json({ error: 'Erreur lors de l\'enregistrement des données' });
  }
});


app.get('/capteurs', async (req, res) => {
  try {
    const capteurs = await Capteur.find();
    if (capteurs.length === 0) {
      return res.status(404).json({ error: 'Aucune donnée de capteur disponible' });
    }
    res.json(capteurs);
  } catch (err) {
    console.error('❌ Erreur lors de la récupération des données :', err);
    res.status(500).json({ error: 'Erreur lors de la récupération des données' });
  }
});

// Login endpoint
app.post('/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    // Find user
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user._id, 
        username: user.username,
        role: user.role 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (err) {
    console.error('❌ Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access denied. No token provided.' });
  }

  try {
    const verified = jwt.verify(token, JWT_SECRET);
    req.user = verified;
    next();
  } catch (err) {
    res.status(403).json({ error: 'Invalid token' });
  }
};

// Admin middleware to check if user has admin role
const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ error: 'Access denied. Admin privileges required.' });
  }
};

// Example of admin-only route
app.get('/admin/dashboard', authenticateToken, isAdmin, async (req, res) => {
  try {
    // Admin-only functionality
    const users = await User.find().select('-password');
    const capteurs = await Capteur.find();
    
    res.json({
      users: users,
      capteurs: capteurs,
      total: {
        users: users.length,
        capteurs: capteurs.length
      }
    });
  } catch (err) {
    res.status(500).json({ error: 'Error fetching admin data' });
  }
});

// Protected route example
app.get('/user/profile', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-password');
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Error fetching user profile' });
  }
});

// --- Add Change Password Endpoint ---
app.post('/user/change-password', authenticateToken, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const userId = req.user.userId; // Get user ID from verified token

  // Basic validation
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current and new passwords are required' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters long' });
  }

  try {
    // Find the user
    const user = await User.findById(userId);
    if (!user) {
      // This shouldn't happen if token is valid, but good to check
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect current password' });
    }

    // Hash the new password
    const hashedNewPassword = await bcrypt.hash(newPassword, 10);

    // Update the password in the database
    user.password = hashedNewPassword;
    await user.save();

    res.json({ message: 'Password updated successfully' });

  } catch (err) {
    console.error('❌ Change Password error:', err);
    res.status(500).json({ error: 'Internal server error during password update' });
  }
});
// --------------------------------

// Admin endpoint to get all pending registrations
app.get('/admin/pending-registrations', authenticateToken, isAdmin, async (req, res) => {
  try {
    const pendingUsers = await PendingUser.find({ status: 'pending' })
      .select('-password')
      .sort({ createdAt: -1 });
    
    res.json(pendingUsers);
  } catch (err) {
    console.error('❌ Fetch pending users error:', err);
    res.status(500).json({ error: 'Error fetching pending registrations' });
  }
});

// Admin endpoint to approve or reject registration
app.post('/admin/registration-decision/:id', authenticateToken, isAdmin, async (req, res) => {
  const { id } = req.params;
  const { decision } = req.body; // 'approve' or 'reject'
  
  try {
    const pendingUser = await PendingUser.findById(id);
    
    if (!pendingUser) {
      return res.status(404).json({ error: 'Pending registration not found' });
    }
    
    if (decision === 'approve') {
      // Create new user
      const newUser = new User({
        username: pendingUser.username,
        email: pendingUser.email,
        password: pendingUser.password,
        role: 'user'
      });
      
      await newUser.save();
      pendingUser.status = 'approved';
      await pendingUser.save();
      
      res.json({ message: 'Registration approved successfully' });
    } else if (decision === 'reject') {
      pendingUser.status = 'rejected';
      await pendingUser.save();
      
      res.json({ message: 'Registration rejected' });
    } else {
      res.status(400).json({ error: 'Invalid decision. Use "approve" or "reject"' });
    }
  } catch (err) {
    console.error('❌ Registration decision error:', err);
    res.status(500).json({ error: 'Error processing registration decision' });
  }
});

// Endpoints for alert thresholds
// Get current thresholds
app.get('/thresholds', authenticateToken, async (req, res) => {
  try {
    let thresholds = await Threshold.findOne().sort({ createdAt: -1 });
    
    if (!thresholds) {
      // Create default thresholds if none exist
      thresholds = new Threshold();
      await thresholds.save();
    }
    
    res.json(thresholds);
  } catch (err) {
    console.error('❌ Fetch thresholds error:', err);
    res.status(500).json({ error: 'Error fetching thresholds' });
  }
});

// Update thresholds (admin only)
app.post('/admin/thresholds', authenticateToken, isAdmin, async (req, res) => {
  // Destructure all expected thresholds from the request body
  const {
    gasThreshold,
    tempThreshold,
    soundThreshold,
    gasWarningThreshold,
    tempWarningThreshold,
    soundWarningThreshold,
    gasDangerThreshold,
    tempDangerThreshold,
    soundDangerThreshold
  } = req.body;

  // Validate that all required fields are numbers
  const requiredFields = [
    gasThreshold, tempThreshold, soundThreshold,
    gasWarningThreshold, tempWarningThreshold, soundWarningThreshold,
    gasDangerThreshold, tempDangerThreshold, soundDangerThreshold
  ];
  
  if (requiredFields.some(field => typeof field !== 'number')) {
    return res.status(400).json({ error: 'All threshold fields must be numbers.' });
  }
  
  // Validate threshold relationships (normal < warning < dangerous)
  if (gasThreshold >= gasWarningThreshold || gasWarningThreshold >= gasDangerThreshold) {
    return res.status(400).json({ 
      error: 'Gas thresholds must follow the pattern: normal < warning < dangerous' 
    });
  }
  
  if (tempThreshold >= tempWarningThreshold || tempWarningThreshold >= tempDangerThreshold) {
    return res.status(400).json({ 
      error: 'Temperature thresholds must follow the pattern: normal < warning < dangerous' 
    });
  }
  
  if (soundThreshold >= soundWarningThreshold || soundWarningThreshold >= soundDangerThreshold) {
    return res.status(400).json({ 
      error: 'Sound thresholds must follow the pattern: normal < warning < dangerous' 
    });
  }

  try {
    // Create a new Threshold document with all the values
    const newThresholds = new Threshold({
      gasThreshold,
      tempThreshold,
      soundThreshold,
      gasWarningThreshold,
      tempWarningThreshold,
      soundWarningThreshold,
      gasDangerThreshold,
      tempDangerThreshold,
      soundDangerThreshold,
      updatedBy: req.user.userId // Record who updated it
    });

    // Save the new set of thresholds
    await newThresholds.save();

    // Verify that the thresholds were saved correctly
    const savedThresholds = await Threshold.findById(newThresholds._id);
    
    // Check if the saved values match what was sent
    const isCorrectlySaved = 
      savedThresholds.gasThreshold === gasThreshold &&
      savedThresholds.tempThreshold === tempThreshold &&
      savedThresholds.soundThreshold === soundThreshold &&
      savedThresholds.gasWarningThreshold === gasWarningThreshold &&
      savedThresholds.tempWarningThreshold === tempWarningThreshold &&
      savedThresholds.soundWarningThreshold === soundWarningThreshold &&
      savedThresholds.gasDangerThreshold === gasDangerThreshold &&
      savedThresholds.tempDangerThreshold === tempDangerThreshold &&
      savedThresholds.soundDangerThreshold === soundDangerThreshold;
    
    if (!isCorrectlySaved) {
      console.warn('⚠️ Thresholds verification failed - saved values don\'t match input');
    }

    // Add verification result to the response
    res.json({
      message: 'Thresholds updated successfully',
      thresholds: savedThresholds,
      verified: isCorrectlySaved
    });
    
  } catch (err) {
    console.error('❌ Update thresholds error:', err);
    res.status(500).json({ error: 'Error updating thresholds' });
  }
});

// Add nodemailer for email notifications
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your.email@gmail.com',     // Replace with your Gmail
    pass: 'your-gmail-password'       // Replace with your password or app password
  }
});

// Import Notification model
const Notification = require('./models/Notification');

// Add notification endpoint
app.post('/notifications', authenticateToken, async (req, res) => {
  try {
    const { type, status, message, value, timestamp } = req.body;
    
    // Get user from database
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Create notification in database
    const notification = new Notification({
      type,
      status,
      message,
      value,
      timestamp: new Date(timestamp),
      user: user._id
    });
    
    await notification.save();

    // Send email for dangerous or warning notifications
    if (status === 'dangerous' || status === 'warning') {
      try {
        const mailOptions = {
          from: 'your.email@gmail.com',  // Same as transporter user
          to: user.email,                // Use user's email from database
          subject: `Sensor Alert: ${type.toUpperCase()} ${status.toUpperCase()}`,
          text: message,
          html: `
            <h2>Sensor Alert</h2>
            <p><strong>Type:</strong> ${type}</p>
            <p><strong>Status:</strong> ${status}</p>
            <p><strong>Value:</strong> ${value}</p>
            <p><strong>Message:</strong> ${message}</p>
            <p><strong>Time:</strong> ${new Date(timestamp).toLocaleString()}</p>
          `
        };

        await transporter.sendMail(mailOptions);
        console.log('Email sent successfully to:', user.email);
      } catch (emailError) {
        console.error('Error sending email:', emailError);
        // Don't fail the request if email fails
      }
    }

    res.status(200).json({ 
      message: 'Notification processed successfully',
      emailSent: status === 'dangerous' || status === 'warning'
    });
  } catch (err) {
    console.error('Notification error:', err);
    res.status(500).json({ error: 'Error processing notification' });
  }
});

// Add test endpoint for connection verification
app.get('/test', (req, res) => {
  res.json({ 
    status: 'ok',
    message: 'Server is running and accessible',
    timestamp: new Date().toISOString()
  });
});

// Add device deregistration endpoint
app.delete('/user/devices/:deviceId', authenticateToken, async (req, res) => {
  const { deviceId } = req.params;
  const userId = req.user.userId;

  try {
    // Find the user
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Remove the device from user's devices array
    user.devices = user.devices.filter(device => device.id !== deviceId);
    await user.save();

    res.json({ 
      message: 'Device deregistered successfully',
      deviceId: deviceId
    });
  } catch (err) {
    console.error('❌ Device deregistration error:', err);
    res.status(500).json({ error: 'Error deregistering device' });
  }
});

// Lancement du serveur
app.listen(port, '0.0.0.0', () => {
  console.log(` Serveur en écoute sur http://0.0.0.0:${port}`);
});
