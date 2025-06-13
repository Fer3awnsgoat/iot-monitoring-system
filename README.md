# IoT Monitoring System

A full-stack IoT monitoring system built with Flutter, Node.js, and MQTT for real-time environmental monitoring and data visualization.

## Features
- 📊 Real-time sensor data monitoring and visualization
- 🔐 Secure user authentication and authorization
- 📱 Cross-platform mobile application (iOS & Android)
- 🔔 Push notifications for threshold alerts
- 📈 Data analytics and statistics
- 👥 Multi-user support with role-based access
- 🔄 MQTT integration for IoT devices
- 📱 Responsive and modern UI

## Project Structure
```
├── lib/                  # Flutter application code
│   ├── screens/         # UI screens
│   ├── providers/       # State management
│   ├── models/          # Data models
│   ├── widgets/         # Reusable UI components
│   └── config.dart      # App configuration
├── mon-backend/         # Node.js backend server
│   ├── routes/         # API routes
│   ├── models/         # Database models
│   ├── middleware/     # Custom middleware
│   └── config/         # Server configuration
└── models/             # Shared data models
```

## Prerequisites
- Flutter SDK (latest stable version)
- Node.js (v14 or higher)
- MongoDB
- MQTT Broker (HiveMQ Cloud or self-hosted)
- Android Studio / Xcode (for mobile development)

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
   ```env
   MONGODB_URI=your_mongodb_uri
   JWT_SECRET=your_jwt_secret
   MQTT_USERNAME=your_mqtt_username
   MQTT_PASSWORD=your_mqtt_password
   MQTT_BROKER=your_mqtt_broker_url
   PORT=3001
   NODE_ENV=development
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
2. Update the `config.dart` file with your server URL:
   ```dart
   static const String _prodUrl = 'your_production_url';
   static const String _devUrl = 'your_development_url';
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Deployment
### Backend Deployment
1. Deploy to Railway:
   ```bash
   railway up
   ```
2. Set environment variables in Railway dashboard
3. Monitor deployment status in Railway logs

### Mobile App Deployment
1. Android:
   ```bash
   flutter build apk --release
   ```
2. iOS:
   ```bash
   flutter build ios --release
   ```

## Security Features
- JWT-based authentication
- Secure password hashing with bcrypt
- HTTPS enforcement in production
- Secure storage for sensitive data
- Role-based access control

## Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support
For support, email [your-email@example.com] or open an issue in the repository.

## Acknowledgments
- Flutter team for the amazing framework
- Node.js community
- HiveMQ for MQTT broker services
