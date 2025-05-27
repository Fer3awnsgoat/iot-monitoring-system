  const express = require('express')
  const router = express.Router()

  const Capteur       = require('../models/Capteur')
  const Threshold     = require('../models/Threshold')
  const Notification  = require('../models/Notification')
  const User          = require('../models/User')
  const { authenticateToken, isAdmin } = require('../middleware/auth')
  const { sendEmail } = require('../utils/email');

  // Fetch last 100 sensor readings
  router.get('/', authenticateToken, async (req, res) => {
    try {
      const capteurs = await Capteur.find()
        .sort({ timestamp: -1 })
        .limit(100)

      if (!capteurs.length) {
        return res.status(404).json({ error: 'No sensor data available' })
      }

      res.json(capteurs)
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'Error fetching sensor data' })
    }
  })

  // Get or init thresholds
  router.get('/thresholds', authenticateToken, async (req, res) => {
    try {
      let thresholds = await Threshold.findOne().sort({ createdAt: -1 })
      if (!thresholds) {
        thresholds = new Threshold()
        await thresholds.save()
      }
      res.json(thresholds)
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'Error fetching thresholds' })
    }
  })

  // Update thresholds (admin only)
  router.post('/thresholds', authenticateToken, isAdmin, async (req, res) => {
    const body = req.body
    const nums = [
      'gasThreshold','gasWarningThreshold','gasDangerThreshold',
      'tempThreshold','tempWarningThreshold','tempDangerThreshold',
      'soundThreshold','soundWarningThreshold','soundDangerThreshold'
    ]

    // ensure all fields present and numbers
    if (nums.some(key => typeof body[key] !== 'number')) {
      return res.status(400).json({ error: 'All threshold fields must be numbers' })
    }

    // ensure normal < warning < danger for each
    if (
      body.gasThreshold    >= body.gasWarningThreshold    ||
      body.gasWarningThreshold >= body.gasDangerThreshold  ||
      body.tempThreshold   >= body.tempWarningThreshold   ||
      body.tempWarningThreshold  >= body.tempDangerThreshold ||
      body.soundThreshold  >= body.soundWarningThreshold  ||
      body.soundWarningThreshold >= body.soundDangerThreshold
    ) {
      return res.status(400).json({
        error: 'Each sensor must follow: normal < warning < danger'
      })
    }

    try {
      const updated = await Threshold.findOneAndUpdate(
        {},
        { ...body, updatedBy: req.user.userId },
        { new: true, upsert: true }
      )
      res.json({ message: 'Thresholds updated', thresholds: updated })
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'Error updating thresholds' })
    }
  })
  router.get('/email-test', async (req, res) => {
    const testConfig = {
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT,
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
      from: process.env.EMAIL_FROM
    };

    try {
      // Test 1: Verify environment variables
      if (!testConfig.host || !testConfig.user || !testConfig.pass) {
        return res.status(500).json({
          error: "SMTP configuration incomplete",
          config: testConfig
        });
      }

      // Test 2: Send actual email
      await sendEmail({
        to: testConfig.user, // Send to yourself
        subject: "SMTP Configuration Test",
        html: `
          <h1>SMTP Test Successful</h1>
          <p>Your configuration:</p>
          <pre>${JSON.stringify(testConfig, null, 2)}</pre>
          <p>Server time: ${new Date()}</p>
        `
      });

      res.json({
        success: true,
        message: "Test email sent successfully",
        config: {
          ...testConfig,
          pass: "***" // Mask password in response
        }
      });
    } catch (error) {
      console.error("Email test failed:", error);
      res.status(500).json({
        error: "Email test failed",
        details: error.message,
        config: {
          ...testConfig,
          pass: "***"
        }
      });
    }
  });
  // List user notifications
  router.get('/notifications', authenticateToken, async (req, res) => {
    try {
      const notifications = await Notification
        .find({ user: req.user.userId })
        .sort({ timestamp: -1 })
      res.json(notifications)
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'Error fetching notifications' })
    }
  })

  // Create a new notification
  router.post('/notifications', authenticateToken, async (req, res) => {
    console.log('→ Enter POST /sensors/notifications');
    console.log('Payload:', req.body);

    let { type, status, message, value, timestamp } = req.body;
    // use provided timestamp or now
    const ts = timestamp ? new Date(timestamp) : new Date();

    if (!type || !status || !message || value === undefined) {
      console.log('Validation failed, missing fields');
      return res.status(400).json({
        error: 'Missing fields: type, status, message, value'
      });
    }

    if (!['normal', 'warning', 'danger'].includes(status)) {
      console.log('Validation failed, bad status:', status);
      return res.status(400).json({
        error: 'Status must be normal, warning or danger'
      });
    }
    try {
  const thresholds = await Threshold.findOne().sort({ createdAt: -1 });
  if (thresholds) {
    // Recalculate status based on actual thresholds
    let actualStatus = 'normal';
    
    if (type === 'temperature') {
      if (value >= thresholds.tempDangerThreshold) {
        actualStatus = 'danger';
      } else if (value >= thresholds.tempWarningThreshold) {
        actualStatus = 'warning';
      }
    } else if (type === 'gas') {
      if (value >= thresholds.gasDangerThreshold) {
        actualStatus = 'danger';
      } else if (value >= thresholds.gasWarningThreshold) {
        actualStatus = 'warning';
      }
    } else if (type === 'sound') {
      if (value >= thresholds.soundDangerThreshold) {
        actualStatus = 'danger';
      } else if (value >= thresholds.soundWarningThreshold) {
        actualStatus = 'warning';
      }
    }
    
    // Override the provided status with the calculated one
    status = actualStatus;
    console.log(`Threshold check: ${type} ${value} -> status: ${actualStatus}`);
  }
} catch (thresholdError) {
  console.error('Error checking thresholds:', thresholdError);
}
    try {
      const user = await User.findById(req.user.userId);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      const notif = new Notification({
        type,
        status,
        message,
        value,
        timestamp: ts,
        user: user._id
      });
      await notif.save();

      // Send email for warning and danger states
      if ((status === 'warning' || status === 'danger') && user.email) {
        try {
          await sendEmail({
            to: user.email,
            subject: `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`,
            html: `
              <div style="padding:20px;background-color:${
                status === 'danger' ? '#ffebee' : '#fff3e0'
              }">
                <h2>Sensor Alert</h2>
                <p><strong>Type:</strong> ${type}</p>
                <p><strong>Status:</strong> ${status}</p>
                <p><strong>Value:</strong> ${value}${type === 'temperature' ? '°C' : type === 'gas' ? 'ppm' : 'dB'}</p>
                <p><strong>Message:</strong> ${message}</p>
                <p><strong>Time:</strong> ${ts.toLocaleString()}</p>
              </div>
            `
          });
          console.log(`Email sent for ${type} alert to ${user.email}`);
        } catch (emailError) {
          console.error('Error sending email:', emailError);
          // Don't fail the request if email fails
        }
      }

      res.status(201).json({ 
        message: 'Notification created successfully',
        notification: notif 
      });
    } catch (err) {
      console.error('Error processing notification:', err.stack);
      res.status(500).json({ error: 'Error processing notification' });
    }
  });

  // Handle sensor data
  router.post('/data', authenticateToken, async (req, res) => {
    try {
      const { temperature, mq2, sound } = req.body;
      console.log('Received sensor data:', { temperature, mq2, sound });
      const user = await User.findById(req.user.userId);
      const thresholds = await Threshold.findOne().sort({ createdAt: -1 });
      
      if (!user || !thresholds) {
        return res.status(500).json({ error: 'Missing user or thresholds' });
      }

  // Parse and validate sensor data before saving
  const capteurData = new Capteur({
    temperature: Number(temperature),
    mq2: Number(mq2),
    sound: Number(sound),
    timestamp: new Date()
  });

  try {
    await capteurData.save();
    console.log('Sensor data saved');
  } catch (err) {
    console.error('Error saving capteur data:', err);
    return res.status(500).json({ error: 'Failed to save sensor data' });
  }

      // Process notifications
      const results = [];
      const checks = [
        {
          type: 'temperature',
          value: temperature,
          warning: thresholds.tempWarningThreshold,
          danger: thresholds.tempDangerThreshold
        },
        {
          type: 'gas',
          value: mq2,
          warning: thresholds.gasWarningThreshold,
          danger: thresholds.gasDangerThreshold
        },
        {
          type: 'sound',
          value: sound,
          warning: thresholds.soundWarningThreshold,
          danger: thresholds.soundDangerThreshold
        }
      ];

      for (const check of checks) {
        let status = 'normal';
        let msg = '';

        if (check.value >= check.danger) {
          status = 'danger';
          msg = `${check.type} too high: ${check.value}`;
        } else if (check.value >= check.warning) {
          status = 'warning';
          msg = `${check.type} elevated: ${check.value}`;
        }

        if (status !== 'normal') {
          const notif = new Notification({
            type: check.type,
            status,
            message: msg,
            value: check.value,
            timestamp: new Date(),
            user: user._id
          });
          await notif.save();

          if (user.email) {
            await sendEmail({
              to: user.email,
              subject: `Alert: ${check.type.toUpperCase()} ${status.toUpperCase()}`,
              html: `
                <div style="padding:20px;background-color:${
                  status === 'danger' ? '#ffebee' : '#fff3e0'
                }">
                  <h2>Sensor Alert</h2>
                  <p><strong>Type:</strong> ${check.type}</p>
                  <p><strong>Status:</strong> ${status}</p>
                  <p><strong>Value:</strong> ${check.value}${check.type === 'temperature' ? '°C' : check.type === 'gas' ? 'ppm' : 'dB'}</p>
                  <p><strong>Message:</strong> ${msg}</p>
                  <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
                </div>
              `
            });
          }

          results.push({ type: check.type, status, message: msg });
        }
      }

      res.json({
        message: 'Sensor data processed',
        data: capteurData,
        alerts: results
      });
    } catch (err) {
      console.error(err.stack);
      res.status(500).json({ error: 'Error processing sensor data' });
    }
  });

  // Test endpoint for sensor data
router.post('/test-data', authenticateToken, async (req, res) => {
  try {
    // Cast inputs to numbers
    const temperature = Number(req.body.temperature);
    const mq2 = Number(req.body.mq2);
    const sound = Number(req.body.sound);

    console.log('Received test sensor data:', { temperature, mq2, sound });

    // Validate inputs are numbers
    if ([temperature, mq2, sound].some(isNaN)) {
      return res.status(400).json({ error: 'Sensor values must be numbers' });
    }

    const user = await User.findById(req.user.userId);
    const thresholds = await Threshold.findOne().sort({ createdAt: -1 });

    if (!user || !thresholds) {
      return res.status(500).json({ error: 'Missing user or thresholds' });
    }

    // Save to Capteur collection
    const capteurData = new Capteur({
      temperature,
      mq2,
      sound,
      timestamp: new Date()
    });
    await capteurData.save();

    // Process notifications
    const results = [];
    const checks = [
      {
        type: 'temperature',
        value: temperature,
        warning: thresholds.tempWarningThreshold,
        danger: thresholds.tempDangerThreshold
      },
      {
        type: 'gas',
        value: mq2,
        warning: thresholds.gasWarningThreshold,
        danger: thresholds.gasDangerThreshold
      },
      {
        type: 'sound',
        value: sound,
        warning: thresholds.soundWarningThreshold,
        danger: thresholds.soundDangerThreshold
      }
    ];

    for (const check of checks) {
      let status = 'normal';
      let msg = '';

      if (check.value >= check.danger) {
        status = 'danger';
        msg = `${check.type} too high: ${check.value}`;
      } else if (check.value >= check.warning) {
        status = 'warning';
        msg = `${check.type} elevated: ${check.value}`;
      }

      if (status !== 'normal') {
        const notif = new Notification({
          type: check.type,
          status,
          message: msg,
          value: check.value,
          timestamp: new Date(),
          user: user._id
        });
        await notif.save();

        if (user.email) {
          await sendEmail({
            to: user.email,
            subject: `Alert: ${check.type.toUpperCase()} ${status.toUpperCase()}`,
            html: `
              <div style="padding:20px;background-color:${
                status === 'danger' ? '#ffebee' : '#fff3e0'
              }">
                <h2>Sensor Alert</h2>
                <p><strong>Type:</strong> ${check.type}</p>
                <p><strong>Status:</strong> ${status}</p>
                <p><strong>Value:</strong> ${check.value}${
                  check.type === 'temperature' ? '°C' : check.type === 'gas' ? 'ppm' : 'dB'
                }</p>
                <p><strong>Message:</strong> ${msg}</p>
                <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
              </div>
            `
          });
        }

        results.push({ type: check.type, status, message: msg });
      }
    }

    res.json({
      message: 'Test data processed',
      data: capteurData,
      alerts: results
    });
  } catch (err) {
    console.error(err.stack);
    res.status(500).json({ error: 'Error processing test data' });
  }
});


  module.exports = router
