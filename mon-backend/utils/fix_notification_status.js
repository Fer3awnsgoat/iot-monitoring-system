// Script to fix notification status values in the database
const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/iot-monitoring-system';

const allowed = ['danger', 'warning', 'normal'];

(async () => {
  try {
    await mongoose.connect(MONGODB_URI, { useNewUrlParser: true, useUnifiedTopology: true });
    console.log('Connected to MongoDB');

    const notifications = await Notification.find({});
    let updated = 0;

    for (const notif of notifications) {
      let status = (notif.status || '').toString().toLowerCase().trim();
      if (!allowed.includes(status)) {
        // Try to normalize common variants
        if (status.startsWith('dang')) status = 'danger';
        else if (status.startsWith('warn')) status = 'warning';
        else if (status.startsWith('norm')) status = 'normal';
        else status = 'normal';
        notif.status = status;
        await notif.save();
        updated++;
        console.log(`Updated notification ${notif._id} to status '${status}'`);
      }
    }
    console.log(`Done. Updated ${updated} notifications.`);
    process.exit(0);
  } catch (err) {
    console.error('Error updating notifications:', err);
    process.exit(1);
  }
})(); 