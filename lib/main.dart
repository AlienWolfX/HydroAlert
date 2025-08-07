import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'widgets/hydro_alert_drawer.dart';
import 'widgets/water_level_trend.dart';
import 'widgets/water_level_status.dart';
import 'models/sensor_reading.dart';
import 'models/device_status.dart';
import 'services/network_scanner.dart';
import 'services/sensor_data_service.dart';

void main() {
  runApp(const HydroAlertApp());
}

class HydroAlertApp extends StatelessWidget {
  const HydroAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroAlert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WaterLevelMonitor(),
    );
  }
}

class WaterLevelMonitor extends StatefulWidget {
  const WaterLevelMonitor({super.key});

  @override
  State<WaterLevelMonitor> createState() => _WaterLevelMonitorState();
}

class _WaterLevelMonitorState extends State<WaterLevelMonitor> {
  double currentWaterLevel = 2.5; // Current water level in meters
  List<FlSpot> waterLevelData = [];
  bool isConnected = false;
  Timer? scanTimer;
  late NetworkScanner networkScanner;
  late SensorDataService sensorDataService;
  bool isScanning = false;
  String? connectedDeviceIp;
  StreamSubscription<SensorReading>? sensorDataSubscription;

  SensorReading? latestReading;
  DateTime? lastUpdateTime;
  DeviceStatus? deviceStatus;
  DateTime? lastDeviceStatusUpdate;
  
  // Alert tracking to prevent spam notifications
  DateTime? lastWarningAlert;
  DateTime? lastDangerAlert;
  static const Duration alertCooldown = Duration(minutes: 5);

  // Connection retry tracking
  int connectionRetries = 0;
  static const int maxRetries = 3;

  // Notification setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  double normalThreshold = 5.0; // Above this distance = normal (water is far)
  double warningThreshold =
      3.5; // Above this distance = warning (water getting closer)
  double dangerThreshold =
      2.0; // Below this distance = danger (water is very close)

  @override
  void initState() {
    super.initState();
    networkScanner = NetworkScanner();
    sensorDataService = SensorDataService(
      onConnectionLost: _onSensorConnectionLost,
    );
    _debugSoundFiles();
    _loadThresholds();
    _initializeNotifications();
    _generateSampleData();
    _startNetworkScanning();
    _setupSensorDataListener();
    // _simulateRealTimeData(); // Disabled simulation
  }

  // Load thresholds from SharedPreferences
  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      normalThreshold = prefs.getDouble('normalThreshold') ?? 5.0;
      warningThreshold = prefs.getDouble('warningThreshold') ?? 3.5;
      dangerThreshold = prefs.getDouble('dangerThreshold') ?? 2.0;
    });
  }

  // Save thresholds to SharedPreferences
  Future<void> _saveThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('normalThreshold', normalThreshold);
    await prefs.setDouble('warningThreshold', warningThreshold);
    await prefs.setDouble('dangerThreshold', dangerThreshold);
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channels with custom sounds
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    // Create separate channels for each alert type with custom sounds
    final AndroidNotificationChannel warningChannel =
        AndroidNotificationChannel(
          'hydroalert_warning',
          'HydroAlert Warning',
          description: 'Warning level water alerts',
          importance: Importance.high,
          sound: const RawResourceAndroidNotificationSound('warning'),
          enableVibration: true,
        );

    final AndroidNotificationChannel dangerChannel = AndroidNotificationChannel(
      'hydroalert_danger',
      'HydroAlert Danger',
      description: 'Critical water level alerts',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('danger'),
      enableVibration: true,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Create the channels
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(warningChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dangerChannel);
  }

  Future<void> _showNotification(
    String title,
    String body, {
    bool isUrgent = false,
    String? soundFileName,
  }) async {
    // Choose the appropriate channel based on urgency and sound
    String channelId;
    if (soundFileName == 'danger') {
      channelId = 'hydroalert_danger';
    } else if (soundFileName == 'warning') {
      channelId = 'hydroalert_warning';
    } else {
      channelId = 'hydroalert_warning'; // fallback
    }

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          channelId == 'hydroalert_danger'
              ? 'HydroAlert Danger'
              : 'HydroAlert Warning',
          channelDescription: channelId == 'hydroalert_danger'
              ? 'Critical water level alerts'
              : 'Warning level water alerts',
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.max : Priority.high,
          color: isUrgent ? Colors.red : Colors.orange,
          playSound: true,
          enableVibration: true,
          // Don't set sound here - it's already set in the channel
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default', // iOS will use default sound for now
        );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      isUrgent ? 1 : 0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _generateSampleData() {
    waterLevelData = [];
  }

  WaterLevelStatus _getWaterLevelStatus() {
    if (latestReading != null) {
      // Primary: Use sensor's status field if available and valid
      if (latestReading!.status.isNotEmpty) {
        String sensorStatus = latestReading!.status.toUpperCase();
        
        switch (sensorStatus) {
          case 'LOW':
            return WaterLevelStatus.normal;
          case 'MEDIUM':
            return WaterLevelStatus.warning;
          case 'HIGH':
            return WaterLevelStatus.danger;
        }
      }
      
      // Secondary: Use distance-based logic with sensor data
      double distance = latestReading!.distance;
      if (distance >= normalThreshold) {
        return WaterLevelStatus.normal;
      } else if (distance >= warningThreshold) {
        return WaterLevelStatus.warning;
      } else if (distance >= dangerThreshold) {
        return WaterLevelStatus.danger;
      }
      
      // Tertiary: Use water level percentage as backup
      if (latestReading!.waterLevel <= 30) {
        return WaterLevelStatus.normal;
      } else if (latestReading!.waterLevel <= 70) {
        return WaterLevelStatus.warning;
      } else {
        return WaterLevelStatus.danger;
      }
    }

    // Fallback to distance-based logic with currentWaterLevel
    if (currentWaterLevel >= normalThreshold) {
      return WaterLevelStatus.normal;
    } else if (currentWaterLevel >= warningThreshold) {
      return WaterLevelStatus.warning;
    } else {
      return WaterLevelStatus.danger;
    }
  }

  Color _getStatusColor(WaterLevelStatus status) {
    switch (status) {
      case WaterLevelStatus.normal:
        return Colors.green;
      case WaterLevelStatus.warning:
        return Colors.orange;
      case WaterLevelStatus.danger:
        return Colors.red;
    }
  }

  String _getStatusText(WaterLevelStatus status) {
    switch (status) {
      case WaterLevelStatus.normal:
        return 'NORMAL';
      case WaterLevelStatus.warning:
        return 'WARNING';
      case WaterLevelStatus.danger:
        return 'DANGER';
    }
  }

  Color _getSensorStatusColor(String sensorStatus) {
    String status = sensorStatus.toUpperCase();
    switch (status) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      case 'NORMAL':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'DANGER':
      case 'CRITICAL':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getLastUpdateTime() {
    if (lastUpdateTime != null) {
      final now = DateTime.now();
      final difference = now.difference(lastUpdateTime!);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    }
    return 'Never';
  }

  Widget _buildRealTimeItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isHighlighted = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Prevent overflow
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(6), // Reduced padding
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: isHighlighted ? 20 : 18, // Reduced icon sizes
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          Flexible(
            // Use Flexible to prevent overflow
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10, // Reduced font size
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Allow wrapping
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Flexible(
            // Use Flexible to prevent overflow
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isHighlighted ? 12 : 11, // Reduced font sizes
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.2,
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 2, // Allow wrapping for longer values
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add a method to test if sound files exist
  void _debugSoundFiles() {
    debugPrint('Testing notification sounds...');
    debugPrint(
      'Warning sound file should be in: android/app/src/main/res/raw/warning',
    );
    debugPrint(
      'Danger sound file should be in: android/app/src/main/res/raw/danger',
    );
  }

  // Method to update thresholds
  void _updateThresholds(double normal, double warning, double danger) {
    setState(() {
      normalThreshold = normal;
      warningThreshold = warning;
      dangerThreshold = danger;
    });
    _saveThresholds(); // Save to persistent storage
  }

  // Show device info dialog
  void _showDeviceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Device Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: deviceStatus != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Device', deviceStatus!.device),
                      _buildInfoRow('Version', deviceStatus!.version),
                      _buildInfoRow(
                        'Icons Version',
                        deviceStatus!.iconsVersion,
                      ),
                      _buildInfoRow(
                        'Serial Number',
                        deviceStatus!.serialNumber,
                      ),
                      _buildInfoRow('Uptime', deviceStatus!.formattedUptime),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi,
                              color: Colors.green[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Connected to $connectedDeviceIp',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Text('Device information not available'),
          ),
          actions: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              onPressed: () {
                _fetchDeviceStatus();
              },
            ),
            FilledButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper widget to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _getWaterLevelStatus();

    // Debug info in UI
    debugPrint('=== Build Method Debug ===');
    debugPrint('Current status in build: $status');
    debugPrint('Is connected: $isConnected');
    debugPrint('Has latest reading: ${latestReading != null}');
    if (latestReading != null) {
      debugPrint('Latest reading status: "${latestReading!.status}"');
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              // Use Flexible to prevent overflow
              child: Text(
                'HydroAlert',
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.blue[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8), // Reduced spacing
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isScanning
                    ? Colors.orange
                    : isConnected
                    ? Colors.green
                    : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color:
                        (isScanning
                                ? Colors.orange
                                : isConnected
                                ? Colors.green
                                : Colors.red)
                            .withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: isScanning
                  ? const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : null,
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: HydroAlertDrawer(
        normalThreshold: normalThreshold,
        warningThreshold: warningThreshold,
        dangerThreshold: dangerThreshold,
        onThresholdsChanged: _updateThresholds,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Real-time Status Card with improved design
            Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey[50]!],
                  ),
                ),
                padding: const EdgeInsets.all(16), // Reduced from 20
                child: Column(
                  children: [
                    // Header with status
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.water_drop,
                            color: _getStatusColor(status),
                            size: 24, // Reduced from 28
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // Prevent overflow
                            children: [
                              Text(
                                'Real-time Status',
                                style: TextStyle(
                                  fontSize: 16, // Reduced from 18
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue[800],
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), // Reduced spacing
                              Row(
                                children: [
                                  const SizedBox(width: 4), // Reduced spacing
                                  // Device info button
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: isConnected
                                            ? Colors.blue[600]
                                            : Colors.grey[400],
                                      ),
                                      onPressed: isConnected
                                          ? () => _showDeviceInfoDialog(context)
                                          : null,
                                      tooltip: isConnected
                                          ? 'Device Info'
                                          : 'Offline',
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ), // Add spacing before status badge
                        Flexible(
                          // Use Flexible for status badge
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(status),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (latestReading != null) ...[
                                  const SizedBox(width: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getSensorStatusColor(
                                        latestReading!.status,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getSensorStatusColor(
                                            latestReading!.status,
                                          ).withOpacity(0.5),
                                          blurRadius: 3,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), 
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildRealTimeItem(
                          'Distance',
                          () {
                            String distanceValue = latestReading != null
                                ? '${latestReading!.distance.toStringAsFixed(1)} cm'
                                : '${currentWaterLevel.toStringAsFixed(1)} cm';
                            return distanceValue;
                          }(),
                          Icons.straighten,
                          latestReading != null
                              ? _getStatusColor(status)
                              : Colors.grey[600]!,
                          isHighlighted: status == WaterLevelStatus.danger,
                        ),
                        _buildRealTimeItem(
                          'Water Level',
                          () {
                            String waterValue = latestReading != null
                                ? '${latestReading!.waterLevel}%'
                                : 'N/A';
                            return waterValue;
                          }(),
                          Icons.water,
                          Colors.blue[600]!,
                          isHighlighted:
                              latestReading != null &&
                              latestReading!.waterLevel > 70,
                        ),
                        _buildRealTimeItem(
                          'Sensor Status',
                          () {
                            String statusValue = latestReading != null
                                ? latestReading!.status.toUpperCase()
                                : 'No Data';
                            return statusValue;
                          }(),
                          Icons.sensors,
                          latestReading != null
                              ? _getSensorStatusColor(latestReading!.status)
                              : Colors.grey[600]!,
                          isHighlighted:
                              latestReading != null &&
                              [
                                'HIGH',
                                'MEDIUM',
                              ].contains(latestReading!.status.toUpperCase()),
                        ),
                        _buildRealTimeItem(
                          'Max Depth',
                          latestReading != null
                              ? '${latestReading!.maxDepth.toStringAsFixed(1)} cm'
                              : 'N/A',
                          Icons.vertical_align_bottom,
                          Colors.purple[600]!,
                        ),
                        _buildRealTimeItem(
                          'Connection',
                          isConnected ? 'LIVE' : 'OFFLINE',
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          isConnected ? Colors.green : Colors.red,
                          isHighlighted: !isConnected,
                        ),
                        _buildRealTimeItem(
                          'Updated',
                          () {
                            String timeValue = _getLastUpdateTime();
                            return timeValue;
                          }(),
                          Icons.access_time,
                          latestReading != null
                              ? Colors.blue
                              : Colors.grey[600]!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Water Level Graph - showing actual water level percentage
            SizedBox(
              height: 400, // Increased from 300 to 400
              child: WaterLevelTrend(
                currentWaterLevel:
                    latestReading?.waterLevel.toDouble() ??
                    0.0, // Use water level percentage
                waterLevelData:
                    waterLevelData, // Already contains proper chart values
                statusColor: _getStatusColor(status),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Network scanning methods
  void _startNetworkScanning() {
    // Only do initial scan, don't set up periodic scanning
    _scanForDevice();
  }

  // Called when sensor connection is lost
  void _onSensorConnectionLost() {
    debugPrint('Sensor connection lost, restarting network scan...');
    setState(() {
      isConnected = false;
      connectedDeviceIp = null;
      deviceStatus = null; 
      lastDeviceStatusUpdate = null;
    });

    // Wait a bit before restarting scan to avoid immediate retry
    Future.delayed(const Duration(seconds: 2), () {
      if (!isConnected) {
        _scanForDevice();
      }
    });
  }

  Future<void> _scanForDevice() async {
    if (isScanning || isConnected) {
      return;
    }

    setState(() {
      isScanning = true;
    });

    try {
      final scanResult = await networkScanner.scanNetwork();

      setState(() {
        isConnected = scanResult != null;
        connectedDeviceIp = scanResult;
        isScanning = false;
      });

      if (isConnected && connectedDeviceIp != null) {
        debugPrint('Device Connected: $connectedDeviceIp');
        connectionRetries = 0; // Reset retry counter on successful connection
        
        sensorDataService.updateDeviceIp(connectedDeviceIp);
        _setupSensorDataListener();
        _fetchDeviceStatus();
      } else {
        debugPrint('No device found on port 65500');
        connectionRetries++;

        // Implement exponential backoff for retries
        final retryDelay = Duration(
          seconds: connectionRetries <= maxRetries ? 10 : 30,
        );

        Future.delayed(retryDelay, () {
          if (!isConnected) {
            _scanForDevice();
          }
        });
      }
    } catch (e) {
      debugPrint('Network scan error: $e');
      setState(() {
        isConnected = false;
        connectedDeviceIp = null;
        isScanning = false;
      });
      
      connectionRetries++;
      final retryDelay = Duration(
        seconds: connectionRetries <= maxRetries ? 10 : 30,
      );

      Future.delayed(retryDelay, () {
        if (!isConnected) {
          _scanForDevice();
        }
      });
    }
  }

  // Fetch device status information
  Future<void> _fetchDeviceStatus() async {
    try {
      debugPrint('=== Fetching Device Status ===');
      final status = await sensorDataService.fetchDeviceStatus();

      if (status != null) {
        setState(() {
          deviceStatus = status;
        });
        debugPrint('Device status updated: ${status.toString()}');
      }
    } catch (e) {
      debugPrint('Failed to fetch device status: $e');
      // Don't set error state since this is not critical for operation
    }
  }

  // Setup sensor data listener
  void _setupSensorDataListener() {
    debugPrint('=== Setting up sensor data listener ===');

    // Cancel existing subscription if any
    sensorDataSubscription?.cancel();
    sensorDataSubscription = null;

    // Check if dataStream is available
    if (sensorDataService.dataStream == null) {
      debugPrint('❌ WARNING: sensorDataService.dataStream is null!');
      debugPrint('Cannot set up listener, stream not available');
      return;
    }

    debugPrint('✅ Data stream is available, setting up listener...');
    sensorDataSubscription = sensorDataService.dataStream!.listen(
      (SensorReading reading) {
        debugPrint('=== Received Sensor Data ===');
        debugPrint('Distance: ${reading.distance} cm');
        debugPrint('Water Level: ${reading.waterLevel}%');
        debugPrint('Status: "${reading.status}"');
        debugPrint('Max Depth: ${reading.maxDepth} cm');

        // Get status before update for comparison
        final oldStatus = latestReading != null ? _getWaterLevelStatus() : null;

        setState(() {
          // Store the complete reading
          latestReading = reading;
          lastUpdateTime = DateTime.now();

          // Use distance as the water level (distance from sensor)
          currentWaterLevel = reading.distance;

          // Add new data point to the chart
          _addDataPointWithTimestamp(reading.distance, reading.timestamp);
        });

        // Check new status and log if changed
        final newStatus = _getWaterLevelStatus();
        if (oldStatus != newStatus) {
          debugPrint('Status changed from $oldStatus to $newStatus');
        }

        // Check for alerts based on the new reading
        _checkAndTriggerAlert();

        // Periodically refresh device status (every 30 seconds)
        final now = DateTime.now();
        if (lastDeviceStatusUpdate == null ||
            now.difference(lastDeviceStatusUpdate!).inSeconds >= 30) {
          _fetchDeviceStatus();
          lastDeviceStatusUpdate = now;
        }
      },
      onError: (error) {
        debugPrint('Sensor data stream error: $error');
        // Connection will be handled by the onConnectionLost callback
      },
    );

    debugPrint('✅ Sensor data listener setup successful');
  }

  // Add data point to the chart with timestamp
  void _addDataPointWithTimestamp(double distance, int timestamp) {
    // Use the actual water level percentage directly from sensor
    double waterLevelPercent = latestReading?.waterLevel.toDouble() ?? 0.0;

    // For the chart, use the percentage directly (not converted to 0-1 range)
    double chartValue = waterLevelPercent;
    chartValue = chartValue.clamp(0.0, 100.0); // Clamp to 0-100%

    // Simple x-value based on current data length
    double xValue = waterLevelData.length.toDouble();

    // Keep only the last 24 data points (2 minutes of data at 5-second intervals)
    if (waterLevelData.length >= 24) {
      waterLevelData.removeAt(0);
  
      // Re-index all points to maintain smooth sequence
      for (int i = 0; i < waterLevelData.length; i++) {
        waterLevelData[i] = FlSpot(i.toDouble(), waterLevelData[i].y);
      }
  
      // New point goes at the end
      xValue = waterLevelData.length.toDouble();
    }

    waterLevelData.add(FlSpot(xValue, chartValue));

    debugPrint(
      'Added data point: waterLevel=$waterLevelPercent%, chartValue=$chartValue, x=$xValue, total points=${waterLevelData.length}',
    );
  }

  // Check water level and trigger alerts if needed
  void _checkAndTriggerAlert() {
    final status = _getWaterLevelStatus();
    final now = DateTime.now();

    // Create alert messages based on sensor status or distance
    String alertMessage = 'Water level warning detected';
    String dangerMessage = 'Critical water level detected!';

    if (latestReading != null) {
      String sensorStatus = latestReading!.status.toUpperCase();
      String formattedDistance = latestReading!.distance.toStringAsFixed(1);

      if (sensorStatus == 'MEDIUM') {
        alertMessage =
            'MEDIUM water level detected - Distance: ${formattedDistance} cm';
      } else if (sensorStatus == 'HIGH') {
        dangerMessage =
            'HIGH water level CRITICAL - Distance: ${formattedDistance} cm';
      }
    }

    // Check for warning alert with cooldown
    if (status == WaterLevelStatus.warning) {
      if (lastWarningAlert == null ||
          now.difference(lastWarningAlert!).compareTo(alertCooldown) >= 0) {
        debugPrint('Water Level Warning: $alertMessage');
        _showNotification(
          'Water Level Warning',
          alertMessage,
          soundFileName: 'warning',
        );
        lastWarningAlert = now;
      }
    }

    // Check for danger alert with cooldown (shorter cooldown for critical alerts)
    if (status == WaterLevelStatus.danger) {
      const criticalCooldown = Duration(minutes: 2);
      if (lastDangerAlert == null ||
          now.difference(lastDangerAlert!).compareTo(criticalCooldown) >= 0) {
        debugPrint('Water Level Alert: $dangerMessage');
        _showNotification(
          'Water Level Alert',
          dangerMessage,
          isUrgent: true,
          soundFileName: 'danger',
        );
        lastDangerAlert = now;
      }
    }
  }

  @override
  void dispose() {
    scanTimer?.cancel();
    sensorDataSubscription?.cancel();
    sensorDataService.dispose();
    super.dispose();
  }
}
