import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'widgets/hydro_alert_drawer.dart';
import 'widgets/water_level_trend.dart';
import 'widgets/water_level_status.dart';
import 'models/water_level_unit.dart';

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
  bool isConnected = true; // Connection status

  // Notification setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Water level thresholds - now mutable (stored in meters internally)
  double normalThreshold = 2.0;
  double warningThreshold = 3.5;
  double dangerThreshold = 5.0;

  // Current display unit
  WaterLevelUnit currentUnit = WaterLevelUnit.meters;

  @override
  void initState() {
    super.initState();
    _debugSoundFiles();
    _loadThresholds();
    _initializeNotifications();
    _generateSampleData();
    // _simulateRealTimeData(); // Disabled simulation
  }

  // Load thresholds from SharedPreferences
  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      normalThreshold = prefs.getDouble('normalThreshold') ?? 2.0;
      warningThreshold = prefs.getDouble('warningThreshold') ?? 3.5;
      dangerThreshold = prefs.getDouble('dangerThreshold') ?? 5.0;

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

  void _triggerTestNotification(WaterLevelStatus status) {
    switch (status) {
      case WaterLevelStatus.warning:
        _showNotification(
          'HydroAlert',
          'Water level has reached ${currentWaterLevel.toStringAsFixed(2)}m. Please monitor closely.',
          soundFileName: 'warning',
        );
        break;
      case WaterLevelStatus.danger:
        _showNotification(
          'HydroAlert',
          'Water level has reached ${currentWaterLevel.toStringAsFixed(2)}m. Immediate action required!',
          isUrgent: true,
          soundFileName: 'danger',
        );
        break;
      case WaterLevelStatus.normal:
        // Normal water levels don't trigger notifications
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Normal water level - no notification needed'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        break;
    }
  }

  void _generateSampleData() {
    final random = Random();
    waterLevelData = List.generate(24, (index) {
      double baseLevel = 2.0 + sin(index * 0.3) * 0.5;
      double noise = (random.nextDouble() - 0.5) * 0.3;
      return FlSpot(index.toDouble(), baseLevel + noise);
    });
  }

  // Simulation disabled - keeping method for future use if needed
  /*
  void _simulateRealTimeData() {
    // Simulate real-time data updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          final random = Random();

          // Simulate occasional connection issues (5% chance)
          if (random.nextDouble() < 0.05) {
            isConnected = false;
          } else if (!isConnected && random.nextDouble() < 0.3) {
            // 30% chance to reconnect if disconnected
            isConnected = true;
          } else if (!isConnected) {
            // Stay disconnected, don't update water level
            _simulateRealTimeData();
            return;
          } else {
            isConnected = true;
          }

          // Only update water level if connected
          if (isConnected) {
            currentWaterLevel = 1.0 + random.nextDouble() * 4.0;

            // Add new data point and remove old ones
            if (waterLevelData.length >= 24) {
              waterLevelData.removeAt(0);
              // Shift x values
              for (int i = 0; i < waterLevelData.length; i++) {
                waterLevelData[i] = FlSpot(i.toDouble(), waterLevelData[i].y);
              }
            }
            waterLevelData.add(
              FlSpot(waterLevelData.length.toDouble(), currentWaterLevel),
            );
          }
        });
        _simulateRealTimeData();
      }
    });
  }
  */

  WaterLevelStatus _getWaterLevelStatus() {
    if (currentWaterLevel <= normalThreshold) {
      return WaterLevelStatus.normal;
    } else if (currentWaterLevel <= warningThreshold) {
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

  // Add a method to test if sound files exist
  void _debugSoundFiles() {
    print('Testing notification sounds...');
    print(
      'Warning sound file should be in: android/app/src/main/res/raw/warning',
    );
    print(
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : Colors.red,
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
}
