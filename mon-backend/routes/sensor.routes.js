const express = require('express');
const router = express.Router();
const Capteur = require('../models/Capteur');
const Threshold = require('../models/Threshold');
const Notification = require('../models/Notification');
const User = require('../models/User')
const { authenticateToken, isAdmin } = require('../middleware/auth');
const { sendEmail } = require('../utils/email');

// Get all sensor data
router.get('/', authenticateToken, async (req, res) => {
  try {
    console.log('Fetching sensor data for user:', req.user.userId);
    
    const capteurs = await Capteur.find()
      .sort({ timestamp: -1 }) // Sort by timestamp descending
      .limit(100); // Limit to last 100 records for performance
    
    if (!capteurs.length) {
      console.log('No sensor data found');
      return res.status(404).json({ error: 'No sensor data available' });
    }
    
    console.log(`Found ${capteurs.length} sensor records`);
    res.json(capteurs);
  } catch (err) {
    console.error('Error fetching sensor data:', err);
    res.status(500).json({ error: 'Error fetching sensor data' });
  }
});

// Get current thresholds
router.get('/thresholds', authenticateToken, async (req, res) => {
  try {
    let thresholds = await Threshold.findOne().sort({ createdAt: -1 });
    if (!thresholds) {
      thresholds = new Threshold();
      await thresholds.save();
    }
    res.json(thresholds);
  } catch (err) {
    res.status(500).json({ error: 'Error fetching thresholds' });
  }
});

// Update thresholds (admin only)
router.post('/thresholds', authenticateToken, isAdmin, async (req, res) => {
  console.log('POST /sensors/thresholds called by user:', req.user);
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

  // Validate thresholds
  const requiredFields = [
    gasThreshold, tempThreshold, soundThreshold,
    gasWarningThreshold, tempWarningThreshold, soundWarningThreshold,
    gasDangerThreshold, tempDangerThreshold, soundDangerThreshold
  ];
  
  if (requiredFields.some(field => typeof field !== 'number')) {
    return res.status(400).json({ error: 'All threshold fields must be numbers' });
  }

  // Validate threshold relationships
  if (gasThreshold >= gasWarningThreshold || gasWarningThreshold >= gasDangerThreshold) {
    return res.status(400).json({ error: 'Gas thresholds must follow: normal < warning < dangerous' });
  }
  
  if (tempThreshold >= tempWarningThreshold || tempWarningThreshold >= tempDangerThreshold) {
    return res.status(400).json({ error: 'Temperature thresholds must follow: normal < warning < dangerous' });
  }
  
  if (soundThreshold >= soundWarningThreshold || soundWarningThreshold >= soundDangerThreshold) {
    return res.status(400).json({ error: 'Sound thresholds must follow: normal < warning < dangerous' });
  }

  try {
    const updatedThresholds = await Threshold.findOneAndUpdate(
      {},
      {
        gasThreshold,
        tempThreshold,
        soundThreshold,
        gasWarningThreshold,
        tempWarningThreshold,
        soundWarningThreshold,
        gasDangerThreshold,
        tempDangerThreshold,
        soundDangerThreshold,
        updatedBy: req.user.userId
      },
      { new: true, upsert: true }
    );

    res.json({
      message: 'Thresholds updated successfully',
      thresholds: updatedThresholds
    });
  } catch (err) {
    res.status(500).json({ error: 'Error updating thresholds' });
  }
});

// Create notification
router.post('/notifications', authenticateToken, async (req, res) => {
  const { type, status, message, value, timestamp } = req.body;
  
  try {
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const notification = new Notification({
      type,
      status,
      message,
      value,
      timestamp: new Date(timestamp),
      user: user._id
    });
    
    await notification.save();

    if ((status === 'dangerous' || status === 'warning') && user.email) {
      await sendEmail({
        to: user.email,
        subject: `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`, // Fixed template literal
        html: `
          <div style="padding: 20px; background-color: ${status === 'dangerous' ? '#ffebee' : '#fff3e0'};">
            <h2>Sensor Alert</h2>
            <p><strong>Type:</strong> ${type}</p>
            <p><strong>Status:</strong> ${status}</p>
            <p><strong>Value:</strong> ${value}</p>
            <p><strong>Message:</strong> ${message}</p>
            <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
          </div>
        `
      });
    }

    res.status(200).json({ 
      message: 'Notification processed successfully',
      notification
    });
  } catch (err) {
    res.status(500).json({ error: 'Error processing notification' });
  }
});

module.exports = router;