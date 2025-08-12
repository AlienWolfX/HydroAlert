# HydroAlert - Water Level Monitoring System 🌊

A comprehensive real-time water level monitoring system built with Flutter that connects to IoT sensors to provide continuous water level tracking with intelligent alerts and threshold-based notifications.

![HydroAlert](assets/icon/icon.png)

## 📖 Overview

HydroAlert is a cross-platform mobile application designed to monitor water levels in real-time using IoT sensors. The app provides continuous monitoring, intelligent alerts, and comprehensive data visualization to help users track water levels efficiently and respond to critical situations promptly.

## ✨ Features

### 🔴 Core Monitoring Features
- **Real-time Water Level Monitoring** - Continuous tracking of water levels with live updates
- **Multi-Device Support** - Detect and connect to multiple HydroAlert sensors on the network
- **Offline Status Handling** - Clear indication when devices go offline with "No Data" display
- **Device Switching** - Easy switching between multiple detected devices
- **Connection Status Indicator** - Real-time connection status with visual feedback

### 📊 Data Visualization
- **Interactive Charts** - Real-time water level trend visualization using FL Chart
- **Historical Data** - Track water level changes over time with smooth animations
- **Status Color Coding** - Visual status indicators (Normal/Warning/Danger)
- **Grid-based Dashboard** - Organized display of key metrics including:
  - Water Level Percentage
  - Distance Measurements
  - Sensor Status
  - Maximum Depth
  - Connection Status
  - Last Update Time

### 🚨 Alert System
- **Intelligent Notifications** - Custom sound alerts for different severity levels
- **Threshold-based Alerts** - Configurable warning and danger thresholds
- **Alert Cooldown** - Prevents spam notifications with intelligent timing
- **Critical Alert Escalation** - Shorter cooldown for critical situations
- **Background Notifications** - Receive alerts even when app is minimized

### ⚙️ Configuration & Settings
- **Customizable Thresholds** - Set custom normal, warning, and danger levels
- **Settings Persistence** - User preferences saved locally
- **Device Information** - Detailed device status and specifications
- **Network Configuration** - Automatic device discovery on local network

### 🎨 User Interface
- **Material Design 3** - Modern, clean interface following Google's design guidelines
- **Responsive Layout** - Optimized for different screen sizes
- **Smooth Animations** - Engaging user experience with fluid transitions
- **Dark/Light Theme Support** - Adapts to system theme preferences
- **Accessibility** - Screen reader support and proper contrast ratios

### 🌐 Network Features
- **Automatic Device Discovery** - Scans local network for available sensors
- **Multiple Device Support** - Handle multiple sensors simultaneously
- **Connection Recovery** - Automatic reconnection on network issues
- **Network Status Monitoring** - Real-time connection health tracking

## 🏗️ Architecture & Components

### 📱 Flutter App Structure

```
lib/
├── main.dart                    # Main application entry point and primary UI
├── models/                      # Data models and structures
│   ├── sensor_reading.dart     # Sensor data structure
│   ├── device_status.dart      # Device information model
│   └── water_level_unit.dart   # Water level unit definitions
├── services/                    # Business logic and API services
│   ├── network_scanner.dart    # Network device discovery
│   └── sensor_data_service.dart # Real-time data processing
└── widgets/                     # Reusable UI components
    ├── hydro_alert_drawer.dart  # Navigation drawer
    ├── water_level_trend.dart   # Chart visualization widget
    ├── water_level_status.dart  # Status display component
    ├── settings_dialog.dart     # Configuration interface
    └── about_dialog.dart        # App information dialog
```

### 🔧 Key Components

#### **Main Application (`main.dart`)**
- **State Management** - Handles app-wide state using StatefulWidget
- **Real-time Updates** - Processes sensor data streams
- **UI Coordination** - Manages all visual components and user interactions
- **Alert Processing** - Triggers notifications based on water levels
- **Device Management** - Handles multiple device connections

#### **Models Directory**
- **SensorReading** - Structures incoming sensor data (distance, water level, status, timestamp)
- **DeviceStatus** - Manages device information (version, uptime, serial number)
- **WaterLevelUnit** - Defines measurement units and conversion logic

#### **Services Directory**
- **NetworkScanner** - Discovers HydroAlert devices on local network using UDP scanning
- **SensorDataService** - Manages real-time data streams and HTTP communication with sensors

#### **Widgets Directory**
- **HydroAlertDrawer** - Side navigation with settings and configuration options
- **WaterLevelTrend** - Interactive chart component using FL Chart library
- **WaterLevelStatus** - Color-coded status indicators and alerts
- **SettingsDialog** - Threshold configuration interface
- **AboutDialog** - App information and version details

### 🔌 IoT Integration

#### **Arduino/Hardware Components**
```
Arduino/
├── Schematic/              # Circuit diagrams and wiring instructions
└── WaterX/                 # Arduino firmware
    ├── WaterX.ino         # Main Arduino sketch
    └── icons.h            # Display icons and graphics
```

#### **Communication Protocol**
- **HTTP REST API** - Communication between app and sensors
- **JSON Data Format** - Structured data exchange
- **Real-time Streaming** - Continuous data updates
- **Network Discovery** - UDP broadcast for device detection

## 🔧 Technical Stack

### **Frontend (Flutter)**
- **Framework**: Flutter SDK 3.8.1+
- **Language**: Dart
- **UI Kit**: Material Design 3
- **Charts**: FL Chart 0.69.0
- **Notifications**: Flutter Local Notifications 17.2.2
- **Storage**: SharedPreferences 2.2.2
- **HTTP Client**: HTTP 1.1.0
- **Network Info**: Network Info Plus 5.0.3

### **Backend (IoT/Arduino)**
- **Microcontroller**: Arduino-compatible board
- **Sensors**: Ultrasonic distance sensors
- **Connectivity**: WiFi module for network communication
- **Protocol**: HTTP/TCP for data transmission

### **Development Tools**
- **IDE**: Visual Studio Code / Android Studio
- **Version Control**: Git
- **Build System**: Flutter build tools
- **Testing**: Flutter testing framework

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK
- Android Studio / Xcode for mobile deployment
- Arduino IDE for hardware programming

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/AlienWolfX/HydroAlert.git
   cd HydroAlert
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure assets**
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

### Hardware Setup
1. Upload the Arduino firmware from `Arduino/WaterX/WaterX.ino`
2. Connect ultrasonic sensors according to the schematic
3. Configure WiFi credentials in the Arduino sketch
4. Deploy the sensor hardware in your monitoring location

## 📊 Usage

1. **Launch the App** - Open HydroAlert on your mobile device
2. **Device Discovery** - App automatically scans for available sensors
3. **Connect** - Select from detected devices or connect to a single device automatically
4. **Monitor** - View real-time water levels, trends, and status updates
5. **Configure** - Set custom thresholds via the settings drawer
6. **Alerts** - Receive notifications when water levels exceed safe thresholds

## 🔧 Configuration

### **Threshold Settings**
- **Normal Level**: Water level considered safe (default: 5.0 cm)
- **Warning Level**: Caution threshold (default: 3.5 cm)
- **Danger Level**: Critical threshold requiring immediate attention (default: 2.0 cm)

### **Notification Settings**
- **Warning Alerts**: 5-minute cooldown between notifications
- **Critical Alerts**: 2-minute cooldown for urgent situations
- **Custom Sounds**: Different notification tones for each alert level

## 🤝 Contributing

We welcome contributions to improve HydroAlert! Please feel free to:
- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **AlienWolfX** - *Initial work and development* - [GitHub](https://github.com/AlienWolfX)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- FL Chart contributors for excellent charting capabilities
- Arduino community for IoT sensor integration
- Material Design team for UI guidelines

## 📞 Support

For support, bug reports, or feature requests, please:
- Open an issue on GitHub
- Contact the development team
- Check the documentation for troubleshooting

---

**HydroAlert** - Keeping you informed about water levels, one sensor at a time! 🌊📱
