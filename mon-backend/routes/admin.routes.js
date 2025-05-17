const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const User = require('../models/User');
const PendingUser = require('../models/PendingUser');
const Capteur = require('../models/Capteur');
const { authenticateToken, isAdmin } = require('../middleware/auth');
const { sendEmail } = require('../utils/email');

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
            const sizeMB = stats.size / (1024 * 1024); // Convert to MB
            totalSize += sizeMB;
            
            collectionStats.push({
                name: collection.name,
                size: sizeMB.toFixed(2),
                documents: stats.count
            });
        }

        // Calculate storage limit and usage
        const storageLimit = "512MB"; // You can adjust this or make it dynamic
        const usagePercentage = ((totalSize / 512) * 100).toFixed(2); // Assuming 512MB limit

        res.json({
            usagePercentage: usagePercentage,
            totalSizeMB: totalSize.toFixed(2),
            storageLimit: storageLimit,
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
  
  try {
    const pendingUser = await PendingUser.findById(id);
    if (!pendingUser) {
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
        await sendEmail({
          to: pendingUser.email,
          subject: 'Welcome to IoT Monitoring System',
          html: `
            <div style="padding: 20px; background-color: #e8f5e9;">
              <h2>Welcome ${pendingUser.username}!</h2>
              <p>Your registration has been approved. You can now log in to the IoT Monitoring System.</p>
              <p>You will receive email notifications at this address for important system alerts.</p>
            </div>
          `
        });
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
    res.status(500).json({ error: 'Error processing registration decision' });
  }
});

// Clear collection data
router.delete('/clear-collection/:collectionName', authenticateToken, isAdmin, async (req, res) => {
  const { collectionName } = req.params;
  const { sizeMB } = req.body;
  
  try {
    if (collectionName.toLowerCase() === 'users') {
      return res.status(403).json({ error: 'Cannot clear users collection' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    if (!collection) {
      return res.status(404).json({ error: 'Collection not found' });
    }

    const stats = await collection.stats();
    const currentSizeMB = (stats.size + stats.totalIndexSize) / (1024 * 1024);

    if (sizeMB >= currentSizeMB) {
      await collection.deleteMany({});
    } else {
      const deleteRatio = sizeMB / currentSizeMB;
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
      clearedSize: sizeMB,
    });
  } catch (err) {
    res.status(500).json({ error: 'Error clearing collection' });
  }
});

module.exports = router;

module.exports = router;