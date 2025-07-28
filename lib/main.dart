import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import 'widgets/hydro_alert_drawer.dart';
import 'widgets/water_level_trend.dart';
import 'widgets/water_level_status.dart';
import 'models/water_level_unit.dart';
import 'models/sensor_reading.dart';
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
  bool isConnected =
      false; // Connection status - starts as false until device is found
  Timer? scanTimer;
  late NetworkScanner networkScanner;
  late SensorDataService sensorDataService;
  bool isScanning = false;
  String? connectedDeviceIp;
  StreamSubscription<SensorReading>? sensorDataSubscription;

  // Notification setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  double normalThreshold = 5.0; // Above this distance = normal (water is far)
  double warningThreshold =
      3.5; // Above this distance = warning (water getting closer)
  double dangerThreshold =
      2.0; // Below this distance = danger (water is very close)

  // Current display unit
  WaterLevelUnit currentUnit = WaterLevelUnit.meters;

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

      // Load unit preference
      final unitIndex = prefs.getInt('waterLevelUnit') ?? 0;
      currentUnit = WaterLevelUnit.values[unitIndex];
    });
  }

  // Save thresholds to SharedPreferences
  Future<void> _saveThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('normalThreshold', normalThreshold);
    await prefs.setDouble('warningThreshold', warningThreshold);
    await prefs.setDouble('dangerThreshold', dangerThreshold);
    await prefs.setInt('waterLevelUnit', currentUnit.index);
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
    final random = Random();
    waterLevelData = List.generate(24, (index) {
      double baseLevel = 2.0 + sin(index * 0.3) * 0.5;
      double noise = (random.nextDouble() - 0.5) * 0.3;
      return FlSpot(index.toDouble(), baseLevel + noise);
    });
  }

  WaterLevelStatus _getWaterLevelStatus() {
    // Descending order logic: lower distance = higher water level = more dangerous
    if (currentWaterLevel >= normalThreshold) {
      return WaterLevelStatus.normal; // Far from sensor = normal
    } else if (currentWaterLevel >= warningThreshold) {
      return WaterLevelStatus.warning; // Getting closer = warning
    } else {
      return WaterLevelStatus.danger; // Very close = danger
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

  // Method to update the display unit
  void _updateUnit(WaterLevelUnit newUnit) {
    setState(() {
      currentUnit = newUnit;
    });
    _saveThresholds(); // Save to persistent storage
  }

  @override
  Widget build(BuildContext context) {
    final status = _getWaterLevelStatus();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('HydroAlert'),
            const SizedBox(width: 8),
            Tooltip(
              message: isScanning
                  ? 'Scanning network...'
                  : isConnected
                  ? 'Device Connected${connectedDeviceIp != null ? ' ($connectedDeviceIp)' : ''}'
                  : 'No device found',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isScanning
                      ? Colors.orange
                      : isConnected
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: HydroAlertDrawer(
        normalThreshold: normalThreshold,
        warningThreshold: warningThreshold,
        dangerThreshold: dangerThreshold,
        currentUnit: currentUnit,
        onThresholdsChanged: _updateThresholds,
        onUnitChanged: _updateUnit,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Water Level Graph
            Expanded(
              flex: 3,
              child: WaterLevelTrend(
                currentWaterLevel: currentWaterLevel,
                waterLevelData: waterLevelData,
                statusColor: _getStatusColor(status),
                normalThreshold: normalThreshold,
                warningThreshold: warningThreshold,
                dangerThreshold: dangerThreshold,
                unit: currentUnit,
              ),
            ),
            const SizedBox(height: 16),

            // Status Indicators
            WaterLevelStatusWidget(currentStatus: status),
            const SizedBox(height: 16),

            // Test Notification Buttons
            // Card(
            //   elevation: 4,
            //   child: Padding(
            //     padding: const EdgeInsets.all(20.0),
            //     child: Column(
            //       children: [
            //         const Text(
            //           'Test Alert Notifications',
            //           style: TextStyle(
            //             fontSize: 18,
            //             fontWeight: FontWeight.bold,
            //           ),
            //         ),
            //         const SizedBox(height: 16),
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //           children: [
            //             ElevatedButton.icon(
            //               onPressed: () =>
            //                   _triggerTestNotification(WaterLevelStatus.normal),
            //               icon: const Icon(
            //                 Icons.check_circle,
            //                 color: Colors.green,
            //               ),
            //               label: const Text('Normal'),
            //               style: ElevatedButton.styleFrom(
            //                 backgroundColor: Colors.green.withOpacity(0.1),
            //                 foregroundColor: Colors.green,
            //                 side: const BorderSide(color: Colors.green),
            //               ),
            //             ),
            //             ElevatedButton.icon(
            //               onPressed: () => _triggerTestNotification(
            //                 WaterLevelStatus.warning,
            //               ),
            //               icon: const Icon(Icons.warning, color: Colors.orange),
            //               label: const Text('Warning'),
            //               style: ElevatedButton.styleFrom(
            //                 backgroundColor: Colors.orange.withOpacity(0.1),
            //                 foregroundColor: Colors.orange,
            //                 side: const BorderSide(color: Colors.orange),
            //               ),
            //             ),
            //             ElevatedButton.icon(
            //               onPressed: () =>
            //                   _triggerTestNotification(WaterLevelStatus.danger),
            //               icon: const Icon(Icons.dangerous, color: Colors.red),
            //               label: const Text('Danger'),
            //               style: ElevatedButton.styleFrom(
            //                 backgroundColor: Colors.red.withOpacity(0.1),
            //                 foregroundColor: Colors.red,
            //                 side: const BorderSide(color: Colors.red),
            //               ),
            //             ),
            //           ],
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
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
      return; // Prevent overlapping scans and don't scan if already connected
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
        // Start fetching sensor data from the connected device
        sensorDataService.updateDeviceIp(connectedDeviceIp);
      } else {
        debugPrint('No device found on port 65500');
        // Schedule retry scan in 10 seconds if no device found
        Future.delayed(const Duration(seconds: 10), () {
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
      // Schedule retry scan in 10 seconds on error
      Future.delayed(const Duration(seconds: 10), () {
        if (!isConnected) {
          _scanForDevice();
        }
      });
    }
  }

  // Setup sensor data listener
  void _setupSensorDataListener() {
    sensorDataSubscription = sensorDataService.dataStream?.listen(
      (SensorReading reading) {
        debugPrint('Received sensor data: ${reading.toString()}');
        
        setState(() {
          // Use distance as the water level (distance from sensor)
          currentWaterLevel = reading.distance;

          // Add new data point to the chart
          _addDataPoint(reading.distance);
        });

        // Check for alerts based on the new reading
        _checkAndTriggerAlert();
      },
      onError: (error) {
        debugPrint('Sensor data stream error: $error');
        // Connection will be handled by the onConnectionLost callback
        // This just logs the error from the stream
      },
    );
  }

  // Add data point to the chart
  void _addDataPoint(double waterLevel) {
    if (waterLevelData.length >= 24) {
      waterLevelData.removeAt(0);
      // Shift x values
      for (int i = 0; i < waterLevelData.length; i++) {
        waterLevelData[i] = FlSpot(i.toDouble(), waterLevelData[i].y);
      }
    }
    waterLevelData.add(FlSpot(waterLevelData.length.toDouble(), waterLevel));
  }

  // Check water level and trigger alerts if needed
  void _checkAndTriggerAlert() {
    final status = _getWaterLevelStatus();

    // Implement notification logic
    if (status == WaterLevelStatus.warning) {
      debugPrint('Water Level Warning: Water is approaching critical level');
      _showNotification(
        'Water Level Warning',
        'Water level is approaching critical level',
        soundFileName: 'warning',
      );
    } else if (status == WaterLevelStatus.danger) {
      debugPrint('Water Level Alert: Critical water level detected!');
      _showNotification(
        'Water Level Alert',
        'Critical water level detected!',
        isUrgent: true,
        soundFileName: 'danger',
      );
    }
  }

  @override
  void dispose() {
    scanTimer?.cancel(); // This will be null most of the time now
    sensorDataSubscription?.cancel();
    sensorDataService.dispose();
    super.dispose();
  }
}
