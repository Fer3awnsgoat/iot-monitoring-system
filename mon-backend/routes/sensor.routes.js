// Create notification
router.post('/notifications', authenticateToken, async (req, res) => {
  try {
    // Validate required fields
    const { type, status, message, value, timestamp } = req.body;
    
    if (!type || !status || !message || value === undefined || !timestamp) {
      return res.status(400).json({ 
        error: 'Missing required fields: type, status, message, value, timestamp' 
      });
    }

    // Validate status
    if (!['normal', 'warning', 'dangerous'].includes(status)) {
      return res.status(400).json({ 
        error: 'Invalid status. Must be one of: normal, warning, dangerous' 
      });
    }

    // Find user
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Create and save notification
    const notification = new Notification({
      type,
      status,
      message,
      value,
      timestamp: new Date(timestamp),
      user: user._id
    });
    
    await notification.save();

    // Send email for alerts
    if ((status === 'dangerous' || status === 'warning') && user.email) {
      try {
        await sendEmail({
          to: user.email,
          subject: `Alert: ${type.toUpperCase()} ${status.toUpperCase()}`,
          html: `
            <div style="padding: 20px; background-color: ${status === 'dangerous' ? '#ffebee' : '#fff3e0'};">
              <h2>Sensor Alert</h2>
              <p><strong>Type:</strong> ${type}</p>
              <p><strong>Status:</strong> ${status}</p>
              <p><strong>Value:</strong> ${value}</p>
              <p><strong>Message:</strong> ${message}</p>
              <p><strong>Time:</strong> ${new Date(timestamp).toLocaleString()}</p>
            </div>
          `
        });
        console.log(`Email sent successfully to ${user.email}`);
      } catch (emailError) {
        console.error('Failed to send email:', emailError);
        // Don't fail the whole request if email fails
      }
    }

    res.status(201).json({ 
      message: 'Notification created successfully',
      notification
    });

  } catch (err) {
    console.error('Error in /notifications:', err);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});