const express = require('express')
const router = express.Router()

const Capteur       = require('../models/Capteur')
const Threshold     = require('../models/Threshold')
const Notification  = require('../models/Notification')
const User          = require('../models/User')
const { authenticateToken, isAdmin } = require('../middleware/auth')
const sendEmail = require('../utils/email')

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

  // ensure normal < warning < dangerous for each
  if (
    body.gasThreshold    >= body.gasWarningThreshold    ||
    body.gasWarningThreshold >= body.gasDangerThreshold  ||
    body.tempThreshold   >= body.tempWarningThreshold   ||
    body.tempWarningThreshold  >= body.tempDangerThreshold ||
    body.soundThreshold  >= body.soundWarningThreshold  ||
    body.soundWarningThreshold >= body.soundDangerThreshold
  ) {
    return res.status(400).json({
      error: 'Each sensor must follow: normal < warning < dangerous'
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
  console.log('POST /notifications payload:', req.body)

  const { type, status, message, value } = req.body
  // use provided timestamp or now
  const ts = req.body.timestamp
    ? new Date(req.body.timestamp)
    : new Date()

  if (!type || !status || !message || value === undefined) {
    console.log('Validation failed, missing fields')
    return res.status(400).json({
      error: 'Missing fields: type, status, message, value'
    })
  }

  if (!['normal','warning','dangerous'].includes(status)) {
    console.log('Validation failed, bad status:', status)
    return res.status(400).json({
      error: 'Status must be normal, warning or dangerous'
    })
  }

  try {
    const user = await User.findById(req.user.userId)
    if (!user) {
      return res.status(404).json({ error: 'User not found' })
    }

    const notif = new Notification({
      type,
      status,
      message,
      value,
      timestamp: ts,
      user: user._id
    })
    await notif.save()

    if ((status==='warning'||status==='dangerous') && user.email) {
      await sendEmail({
        to: user.email,
        subject: `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`,
        html: `
          <div style="padding:20px;background-color:${
            status==='dangerous'? '#ffebee':'#fff3e0'
          }">
            <h2>Sensor Alert</h2>
            <p><strong>Type:</strong> ${type}</p>
            <p><strong>Status:</strong> ${status}</p>
            <p><strong>Value:</strong> ${value}</p>
            <p><strong>Message:</strong> ${message}</p>
            <p><strong>Time:</strong> ${ts.toLocaleString()}</p>
          </div>
        `
      })
    }

    res.status(201).json({ message: 'Notification created', notification: notif })
  } catch (err) {
    console.error('Error processing notification:', err.stack)
    res.status(500).json({ error: 'Error processing notification' })
  }
})


module.exports = router
