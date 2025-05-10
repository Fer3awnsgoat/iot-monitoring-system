const mongoose = require('mongoose');

// Définir le schéma du capteur
const capteurSchema = new mongoose.Schema({
  sound: { type: Number, required: true },
  mq2: { type: Number, required: true },
  temperature: { type: Number, required: true },
  timestamp: { type: Date, default: Date.now },
});

// Créer le modèle basé sur le schéma
const Capteur = mongoose.model('Capteur', capteurSchema);

// Exporter le modèle
module.exports = Capteur;
