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

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **AlienWolfX** - *Initial work and development* - [GitHub](https://github.com/AlienWolfX)

---
