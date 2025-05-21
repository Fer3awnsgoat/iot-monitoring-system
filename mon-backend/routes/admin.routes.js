const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const User = require('../models/User');
const PendingUser = require('../models/PendingUser');
const Capteur = require('../models/Capteur');
const { authenticateToken, isAdmin } = require('../middleware/auth');
const { sendEmail } = require('../utils/email');
const Notification = require('../models/Notification');

// Get admin dashboard data
router.get('/dashboard', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [users, capteurs] = await Promise.all([
      User.find().select('-password'),
      Capteur.find()
    ]);
    
    res.json({
      users,
      capteurs,
      total: { users: users.length, capteurs: capteurs.length }
    });
  } catch (err) {
    res.status(500).json({ error: 'Error fetching admin data' });
  }
});

// Get database stats
router.get('/database-stats', authenticateToken, isAdmin, async (req, res) => {
    try {
        // Get all collections
        const collections = await mongoose.connection.db.listCollections().toArray();
        
        // Initialize stats array
        const collectionStats = [];
        let totalSize = 0;

        // Get stats for each collection
        for (const collection of collections) {
            const stats = await mongoose.connection.db.collection(collection.name).stats();
            const sizeKB = stats.size / 1024; // Convert to KB
            totalSize += sizeKB;
            
            collectionStats.push({
                name: collection.name,
                size: sizeKB.toFixed(2), // Show 2 decimals
                documents: stats.count
            });
        }

        // Calculate storage limit and usage (512MB = 524288KB)
        const storageLimit = 524288; // KB
        const usagePercentage = ((totalSize / storageLimit) * 100).toFixed(2);

        res.json({
            usagePercentage: usagePercentage,
            totalSizeKB: totalSize.toFixed(2),
            storageLimit: `${storageLimit}KB`,
            collections: collectionStats
        });
    } catch (error) {
        console.error('Error fetching database stats:', error);
        res.status(500).json({ error: 'Failed to fetch database statistics' });
    }
});

// Get pending registrations
router.get('/pending-registrations', authenticateToken, isAdmin, async (req, res) => {
  try {
    const pendingUsers = await PendingUser.find({ status: 'pending' })
      .select('-password')
      .sort({ createdAt: -1 });
    
    res.json(pendingUsers);
  } catch (err) {
    res.status(500).json({ error: 'Error fetching pending registrations' });
  }
});

// Handle registration decision
router.post('/registration-decision/:id', authenticateToken, isAdmin, async (req, res) => {
  const { id } = req.params;
  const { decision } = req.body;
  console.log('Registration decision called for id:', id, 'decision:', decision);
  
  try {
    const pendingUser = await PendingUser.findById(id);
    if (!pendingUser) {
      console.log('Pending user not found for id:', id);
      return res.status(404).json({ error: 'Pending registration not found' });
    }

    if (decision === 'approve') {
      const newUser = new User({
        username: pendingUser.username,
        email: pendingUser.email,
        password: pendingUser.password,
        role: 'user'
      });
      
      await newUser.save();
      pendingUser.status = 'approved';
      await pendingUser.save();

      if (pendingUser.email) {
        console.log('Attempting to send welcome email to:', pendingUser.email);
        try {
        await sendEmail({
          to: pendingUser.email,
          subject: 'Welcome to IoT Monitoring System',
            html: `<div style="padding: 20px; background-color: #e8f5e9;">
              <h2>Welcome ${pendingUser.username}!</h2>
              <p>Your registration has been approved. You can now log in to the IoT Monitoring System.</p>
              <p>You will receive email notifications at this address for important system alerts.</p>
            </div>`
        });
          console.log('Welcome email sent to:', pendingUser.email);
        } catch (emailErr) {
          console.error('Failed to send welcome email:', emailErr);
          // Do not throw, just log
        }
      }
      
      res.json({ message: 'Registration approved successfully' });
    } else if (decision === 'reject') {
      pendingUser.status = 'rejected';
      await pendingUser.save();
      res.json({ message: 'Registration rejected' });
    } else {
      res.status(400).json({ error: 'Invalid decision. Use "approve" or "reject"' });
    }
  } catch (err) {
    console.error('Error in registration decision:', err);
    res.status(500).json({ error: 'Error processing registration decision' });
  }
});

// Clear collection data
router.delete('/clear-collection/:collectionName', authenticateToken, isAdmin, async (req, res) => {
  const { collectionName } = req.params;
  const { sizeKB } = req.body;
  
  try {
    if (collectionName.toLowerCase() === 'users') {
      return res.status(403).json({ error: 'Cannot clear users collection' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    if (!collection) {
      return res.status(404).json({ error: 'Collection not found' });
    }

    const stats = await collection.stats();
    const currentSizeKB = (stats.size + stats.totalIndexSize) / 1024;

    if (sizeKB >= currentSizeKB) {
      await collection.deleteMany({});
    } else {
      const deleteRatio = sizeKB / currentSizeKB;
      const documentsToDelete = Math.floor(stats.count * deleteRatio);
      const documentsToRemove = await collection
        .find({})
        .sort({ timestamp: 1 })
        .limit(documentsToDelete)
        .toArray();

      if (documentsToRemove.length > 0) {
        const lastTimestamp = documentsToRemove[documentsToRemove.length - 1].timestamp;
        await collection.deleteMany({ timestamp: { $lte: lastTimestamp } });
      }
    }
    
    res.json({ 
      message: `Collection ${collectionName} cleared successfully`,
      clearedSize: sizeKB,
    });
  } catch (err) {
    res.status(500).json({ error: 'Error clearing collection' });
  }
});

// Get all notifications for the logged-in user
router.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const notifications = await Notification.find({ user: req.user.userId })
      .sort({ timestamp: -1 }); // Newest first

    res.json(notifications);
  } catch (err) {
    console.error('Error fetching notifications:', err);
    res.status(500).json({ error: 'Error fetching notifications' });
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

// Get all users (Admin only)
router.get('/users', authenticateToken, isAdmin, async (req, res) => {
  try {
    // Find all users and exclude their password field for security
    const users = await User.find().select('-password');
    res.json(users);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ error: 'Error fetching users' });
  }
});

// Admin - Update user role
router.put('/users/:userId/role', authenticateToken, isAdmin, async (req, res) => {
  const { userId } = req.params;
  const { role } = req.body;

  // Validate role
  if (!['user', 'admin'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role specified.' });
  }

  try {
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    user.role = role;
    await user.save();

    res.json({ message: 'User role updated successfully.', user });
  } catch (err) {
    console.error('Error updating user role:', err);
    res.status(500).json({ error: 'Error updating user role.' });
  }
});

// Admin - Update user email (requires admin password)
router.put('/users/:userId/email', authenticateToken, isAdmin, async (req, res) => {
  const { userId } = req.params;
  const { newEmail, adminPassword } = req.body;

  // Basic email format validation (can be enhanced)
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(newEmail)) {
    return res.status(400).json({ error: 'Invalid email format.' });
  }

  try {
    // Authenticate the admin user making the request
    const adminUser = await User.findById(req.user.userId);
    if (!adminUser) {
      // This should not happen if authenticateToken middleware works correctly,
      // but as a safeguard:
      return res.status(401).json({ error: 'Admin user not found.' });
    }

    // Verify the admin's password
    const isPasswordValid = await adminUser.comparePassword(adminPassword); // Assuming comparePassword method on User model
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Incorrect admin password.' });
    }

    // Find the user to be updated
    const userToUpdate = await User.findById(userId);
    if (!userToUpdate) {
      return res.status(404).json({ error: 'User to update not found.' });
    }

    // Check if the new email is already in use by another user
    const existingUserWithEmail = await User.findOne({ email: newEmail });
    if (existingUserWithEmail && existingUserWithEmail._id.toString() !== userId) {
      return res.status(400).json({ error: 'Email already in use by another user.' });
    }

    // Update the user's email
    userToUpdate.email = newEmail;
    await userToUpdate.save();

    // Fetch the updated user to return (without password)
    const updatedUser = await User.findById(userId).select('-password');

    res.json({ message: 'User email updated successfully.', user: updatedUser });
  } catch (err) {
    console.error('Error updating user email:', err);
    res.status(500).json({ error: 'Error updating user email.' });
  }
});

module.exports = router;