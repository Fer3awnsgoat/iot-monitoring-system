const express = require('express');
const router = express.Router();
const Threshold = require('../models/Threshold');
const authMiddleware = require('../middleware/auth');

// Get all thresholds in your original format
router.get('/', authMiddleware, async (req, res) => {
  try {
    const thresholds = await Threshold.find({ userId: req.user.id });
    
    // Transform to your original format
    const result = {
      gasThreshold: thresholds.find(t => t.sensorType === 'gas' && t.level === 'normal')?.value || 300,
      tempThreshold: thresholds.find(t => t.sensorType === 'temperature' && t.level === 'normal')?.value || 30,
      soundThreshold: thresholds.find(t => t.sensorType === 'sound' && t.level === 'normal')?.value || 60,
      gasWarningThreshold: thresholds.find(t => t.sensorType === 'gas' && t.level === 'warning')?.value || 450,
      tempWarningThreshold: thresholds.find(t => t.sensorType === 'temperature' && t.level === 'warning')?.value || 40,
      soundWarningThreshold: thresholds.find(t => t.sensorType === 'sound' && t.level === 'warning')?.value || 80,
      gasDangerThreshold: thresholds.find(t => t.sensorType === 'gas' && t.level === 'danger')?.value || 600,
      tempDangerThreshold: thresholds.find(t => t.sensorType === 'temperature' && t.level === 'danger')?.value || 50,
      soundDangerThreshold: thresholds.find(t => t.sensorType === 'sound' && t.level === 'danger')?.value || 100
    };

    res.json(result);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Bulk update endpoint that works with your Flutter frontend
router.post('/bulk', authMiddleware, async (req, res) => {
  try {
    const { 
      gasThreshold, tempThreshold, soundThreshold,
      gasWarningThreshold, tempWarningThreshold, soundWarningThreshold,
      gasDangerThreshold, tempDangerThreshold, soundDangerThreshold
    } = req.body;

    // Prepare all threshold updates
    const updates = [
      { sensorType: 'gas', level: 'normal', value: gasThreshold },
      { sensorType: 'temperature', level: 'normal', value: tempThreshold },
      { sensorType: 'sound', level: 'normal', value: soundThreshold },
      { sensorType: 'gas', level: 'warning', value: gasWarningThreshold },
      { sensorType: 'temperature', level: 'warning', value: tempWarningThreshold },
      { sensorType: 'sound', level: 'warning', value: soundWarningThreshold },
      { sensorType: 'gas', level: 'danger', value: gasDangerThreshold },
      { sensorType: 'temperature', level: 'danger', value: tempDangerThreshold },
      { sensorType: 'sound', level: 'danger', value: soundDangerThreshold }
    ];

    // Process all updates
    const results = await Promise.all(
      updates.map(update => 
        Threshold.findOneAndUpdate(
          {
            userId: req.user.id,
            sensorType: update.sensorType,
            level: update.level
          },
          {
            value: update.value,
            originalField: `${update.sensorType}${update.level === 'normal' ? 'Threshold' : 
                          update.level === 'warning' ? 'WarningThreshold' : 'DangerThreshold'}`
          },
          {
            new: true,
            upsert: true
          }
        )
      )
    );

    res.json({
      success: true,
      updatedCount: results.length,
      thresholds: {
        gasThreshold: results.find(r => r.sensorType === 'gas' && r.level === 'normal')?.value,
        tempThreshold: results.find(r => r.sensorType === 'temperature' && r.level === 'normal')?.value,
        // Include all other fields similarly...
      }
    });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

module.exports = router;