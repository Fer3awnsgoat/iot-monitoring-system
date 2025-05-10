# IoT Monitoring System

A full-stack IoT monitoring system built with Flutter, Node.js, and MQTT.

## Project Structure

- `lib/` - Flutter application code
- `mon-backend/` - Node.js backend server
- `models/` - Data models for both frontend and backend

## Setup Instructions

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd mon-backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create a `.env` file with the following variables:
   ```
   MONGODB_URI=your_mongodb_uri
   JWT_SECRET=your_jwt_secret
   MQTT_USERNAME=your_mqtt_username
   MQTT_PASSWORD=your_mqtt_password
   MQTT_BROKER=your_mqtt_broker_url
   ```
4. Start the server:
   ```bash
   npm start
   ```

### Flutter App Setup
1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
2. Update the `config.dart` file with your server URL
3. Run the app:
   ```bash
   flutter run
   ```

## Features
- Real-time sensor data monitoring
- User authentication
- MQTT integration for IoT devices
- Push notifications
- Data visualization

## Technologies Used
- Flutter
- Node.js
- Express.js
- MongoDB
- MQTT (HiveMQ Cloud)
- JWT Authentication
