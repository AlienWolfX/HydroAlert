# HydroAlert 🌊

A real-time water level monitoring system built with Flutter that connects to IoT sensors to provide continuous water level tracking with intelligent alerts and threshold-based notifications.

## 📋 Overview

HydroAlert is a mobile application designed for monitoring water levels in real-time using distance sensors (like ultrasonic sensors). The system automatically scans your local network for compatible sensor devices, connects to them, and provides continuous monitoring with customizable alert thresholds.

### Key Features

- **Real-time Monitoring**: Fetches sensor data every 5 seconds from HTTP API endpoint
- **JSON Data Parsing**: Automatically parses sensor readings with distance, waterLevel, status, and more
- **Intelligent Network Discovery**: Automatically scans and connects to sensor devices on your network
- **Threshold-based Alerts**: Configurable Normal, Warning, and Danger thresholds
- **Multi-unit Support**: Display readings in meters, centimeters, feet, or inches
- **Visual Data Trends**: 24-hour historical data visualization with charts
- **Push Notifications**: Custom sound alerts for warning and danger levels
- **Sensor Information Display**: Shows complete sensor data including status and max depth
- **Persistent Settings**: User preferences saved locally
- **Connection Management**: Automatic reconnection when devices become available

## 🏗️ System Architecture

### Frontend (Mobile App)

- **Framework**: Flutter 3.x
- **Language**: Dart
- **UI Components**: Material Design 3
- **Charts**: FL Chart library for data visualization
- **State Management**: StatefulWidget with setState

### Backend/IoT Integration

- **Communication**: HTTP REST API
- **Network Protocol**: TCP/IP over Wi-Fi
- **Data Format**: JSON
- **Sensor Interface**: Distance sensor (ultrasonic/laser)
- **Port**: 65500

### Data Flow

```
IoT Sensor → HTTP API (Port 65500) → Network Scanner → JSON Parser → Flutter App → Chart Display
```

## 🛠️ Technologies Used

### Flutter/Dart Dependencies

- **flutter**: Core framework
- **fl_chart**: Data visualization and trending charts
- **flutter_local_notifications**: Push notifications with custom sounds
- **shared_preferences**: Local storage for settings persistence
- **http**: HTTP client for API communication
- **network_info_plus**: Network device discovery
- **permission_handler**: Android permissions management

### IoT/Hardware Integration

- **HTTP REST API**: Endpoint at `{{device_ip}}:65500/api/readings`
- **JSON Response Format**:
  ```json
  {
    "distance": 24.74,
    "waterLevel": 42,
    "status": "LOW",
    "timestamp": 996546,
    "maxDepth": 43.18
  }
  ```

### Network & Communication

- **Port Scanning**: Automatic device discovery on port 65500
- **Timeout Handling**: 10-second request timeout with retry logic
- **Connection Recovery**: Automatic reconnection on network issues

## 📁 Project Structure

```
lib/
├── main.dart                    # Main app entry point and core logic
├── models/
│   ├── sensor_reading.dart      # JSON data model for sensor readings
│   └── water_level_unit.dart    # Unit conversion enums (m, cm, ft, in)
├── services/
│   ├── network_scanner.dart     # Network device discovery
│   └── sensor_data_service.dart # HTTP API communication & JSON parsing
└── widgets/
    ├── hydro_alert_drawer.dart  # Settings drawer
    ├── settings_dialog.dart     # Threshold configuration
    ├── water_level_status.dart  # Status indicators
    └── water_level_trend.dart   # Data visualization charts
```

## 📊 JSON Data Parsing & Display

### Sensor Reading Model

The app automatically parses JSON responses into a structured `SensorReading` object:

```dart
class SensorReading {
  final double distance;     // Distance from sensor (meters)
  final int waterLevel;      // Water level reading
  final String status;       // Sensor status (LOW, NORMAL, HIGH, etc.)
  final int timestamp;       // Unix timestamp
  final double maxDepth;     // Maximum depth measurement
}
```

### Chart Integration

- **Real-time Updates**: Chart updates every 5 seconds with new sensor data
- **Time-based Plotting**: Uses timestamps for accurate time-series visualization
- **24-hour History**: Maintains rolling 24-hour data window
- **Unit Conversion**: Displays data in user-selected units (m, cm, ft, in)

### Sensor Information Display

The app shows a comprehensive sensor data card including:

- **Distance**: Current distance reading in selected units
- **Water Level**: Raw water level value from sensor
- **Status**: Current sensor status (from JSON)
- **Max Depth**: Maximum measurable depth

## ⚙️ Configuration

### Sensor API Requirements

Your IoT device must expose an HTTP endpoint at:

- **URL**: `http://{{device_ip}}:65500/api/readings`
- **Method**: GET
- **Response**: JSON format with required fields
- **Content-Type**: `application/json`

### Required JSON Fields

- `distance` (number): Distance measurement in meters
- `waterLevel` (number): Water level reading
- `status` (string): Current sensor status
- `timestamp` (number): Unix timestamp
- `maxDepth` (number): Maximum depth measurement

### Threshold Logic (Descending Order)

The system uses distance-based thresholds where:

- **Higher distances** = Water far from sensor = Normal (Green)
- **Medium distances** = Water getting closer = Warning (Orange)
- **Lower distances** = Water very close = Danger (Red)

Example default thresholds:

- Normal: ≥ 5.0m (water is far)
- Warning: ≥ 3.5m (water getting closer)
- Danger: < 3.5m (water very close)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / VS Code
- Compatible IoT sensor device on local network

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/AlienWolfX/hydroalert.git
   cd hydroalert
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Add notification sounds** (Optional)

   - Place `warning.mp3` in `android/app/src/main/res/raw/`
   - Place `danger.mp3` in `android/app/src/main/res/raw/`

4. **Run the application**
   ```bash
   flutter run
   ```

### Network Setup

1. Ensure your mobile device and IoT sensor are on the same Wi-Fi network
2. Configure your sensor to expose the API at port 65500
3. The app will automatically scan for devices on port 65500
4. Once connected, real-time monitoring begins automatically

## 🔧 Customization

### Threshold Configuration

- Open the app drawer (hamburger menu)
- Adjust Normal, Warning, and Danger thresholds
- Select preferred unit of measurement
- Settings are automatically saved

### Notification Sounds

- Replace audio files in `android/app/src/main/res/raw/`
- Supported formats: MP3, WAV
- Files: `warning` and `danger` (without extension)

## 📊 Monitoring Features

### Real-time Display

- Current water level with color-coded status
- Connection status indicator in app bar
- Live updating every 5 seconds
- Complete sensor information card

### Historical Data

- 24-hour trending chart with real sensor data
- Threshold lines overlay
- Automatic data point management
- Time-based X-axis plotting

### Alert System

- Visual status indicators
- Push notifications with custom sounds
- Threshold-based triggering
- Sensor status integration

## 🔍 Troubleshooting

### Connection Issues

- Verify both devices are on same network
- Check if IoT device is responding on port 65500
- Monitor debug logs for network scan results
- Ensure JSON response format is correct

### Data Not Updating

- Check network connectivity
- Verify API endpoint is accessible
- Review JSON response format
- Check threshold configuration

### JSON Parsing Errors

- Verify all required fields are present in JSON response
- Check data types match expected format
- Monitor debug logs for parsing errors
- Validate JSON format using online tools

### Notification Problems

- Ensure notification permissions are granted
- Verify sound files are properly placed
- Check notification channel settings

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support, please open an issue on GitHub or contact the development team.

---

**Built with ❤️ using Flutter for reliable water level monitoring and real-time JSON data visualization**
