const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const auth = require('../middleware/auth');
const isAdmin = require('../middleware/isAdmin');

// GET /admin/database-stats
router.get('/database-stats', auth, isAdmin, async (req, res) => {
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

// POST /admin/clear-collection/:collectionName
router.delete('/clear-collection/:collectionName', auth, isAdmin, async (req, res) => {
    try {
        const { collectionName } = req.params;
        const { sizeMB } = req.body;

        // Get collection
        const collection = mongoose.connection.db.collection(collectionName);
        
        // Get current documents count
        const count = await collection.countDocuments();
        
        if (count === 0) {
            return res.status(400).json({ error: 'Collection is already empty' });
        }

        // Calculate how many documents to delete based on size
        const stats = await collection.stats();
        const totalSizeMB = stats.size / (1024 * 1024);
        const deleteRatio = sizeMB / totalSizeMB;
        const documentsToDelete = Math.floor(count * deleteRatio);

        // Find oldest documents and delete them
        await collection.find()
            .sort({ timestamp: 1 })
            .limit(documentsToDelete)
            .toArray()
            .then(docs => {
                const ids = docs.map(doc => doc._id);
                return collection.deleteMany({ _id: { $in: ids } });
            });

        res.json({ message: 'Collection data cleared successfully' });
    } catch (error) {
        console.error('Error clearing collection:', error);
        res.status(500).json({ error: 'Failed to clear collection data' });
    }
});

module.exports = router; 