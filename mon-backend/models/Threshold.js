const mongoose = require('mongoose');

const thresholdSchema = new mongoose.Schema({
  // Normal thresholds (maximum acceptable values)
  gasThreshold: {
    type: Number,
    default: 300
  },
  tempThreshold: {
    type: Number, 
    default: 25
  },
  soundThreshold: {
    type: Number,
    default: 60
  },
  
  // Warning thresholds (values before becoming dangerous)
  gasWarningThreshold: {
    type: Number,
    default: 450
  },
  tempWarningThreshold: {
    type: Number,
    default: 27
  },
  soundWarningThreshold: {
    type: Number,
    default: 80
  },

  // Dangerous thresholds (values that trigger alert)
  gasDangerThreshold: {
    type: Number,
    default: 600
  },
  tempDangerThreshold: {
    type: Number,
    default: 31
  },
  soundDangerThreshold: {
    type: Number,
    default: 100
  },
  
  updatedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Threshold', thresholdSchema); 