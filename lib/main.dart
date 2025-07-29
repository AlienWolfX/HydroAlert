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
    // Debug: Print current readings
    if (latestReading != null) {
      debugPrint('=== Status Debug ===');
      debugPrint('Sensor status: "${latestReading!.status}"');
      debugPrint('Status uppercase: "${latestReading!.status.toUpperCase()}"');
      debugPrint('Status isEmpty: ${latestReading!.status.isEmpty}');
      debugPrint('Distance: ${latestReading!.distance}');
      debugPrint('Water Level: ${latestReading!.waterLevel}');
    }

    // Use sensor's status field if available, otherwise fall back to distance thresholds
    if (latestReading != null && latestReading!.status.isNotEmpty) {
      String sensorStatus = latestReading!.status.toUpperCase();

      debugPrint('Using sensor status: $sensorStatus');

      if (sensorStatus == 'LOW') {
        debugPrint('Status determined: NORMAL (from LOW)');
        return WaterLevelStatus.normal; // Low water level = normal
      } else if (sensorStatus == 'MEDIUM') {
        debugPrint('Status determined: WARNING (from MEDIUM)');
        return WaterLevelStatus.warning; // Medium water level = warning
      } else if (sensorStatus == 'HIGH') {
        debugPrint('Status determined: DANGER (from HIGH)');
        return WaterLevelStatus.danger; // High water level = danger
      } else {
        debugPrint(
          'Unknown sensor status: $sensorStatus, falling back to distance',
        );
      }
    } else {
      debugPrint('No sensor status available, using distance thresholds');
    }

    // Fallback to distance-based logic if sensor status is not available
    debugPrint('Using distance-based logic: $currentWaterLevel vs thresholds');
    if (currentWaterLevel >= normalThreshold) {
      debugPrint('Status determined: NORMAL (distance-based)');
      return WaterLevelStatus.normal; // Far from sensor = normal
    } else if (currentWaterLevel >= warningThreshold) {
      debugPrint('Status determined: WARNING (distance-based)');
      return WaterLevelStatus.warning; // Getting closer = warning
    } else {
      debugPrint('Status determined: DANGER (distance-based)');
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
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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

  // Method to update the display unit
  void _updateUnit(WaterLevelUnit newUnit) {
    setState(() {
      currentUnit = newUnit;
    });
    _saveThresholds(); // Save to persistent storage
  }

  // Show device info dialog
  void _showDeviceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Device'),
            ],
          ),
          content: deviceStatus != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Device', deviceStatus!.device),
                    _buildInfoRow('Version', deviceStatus!.version),
                    _buildInfoRow('Icons Version', deviceStatus!.iconsVersion),
                    _buildInfoRow('Uptime', deviceStatus!.formattedUptime),
                  ],
                )
              : const Text('Device information not available'),
          actions: <Widget>[
            TextButton(
              child: const Text('Refresh'),
              onPressed: () {
                _fetchDeviceStatus();
              },
            ),
            TextButton(
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Real-time Status Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop,
                          color: _getStatusColor(status),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Real-time Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Device info button
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.info_outline,
                                    size: 16,
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
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getStatusColor(status),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              if (latestReading != null) ...[
                                const SizedBox(width: 6), // Reduced spacing
                                Container(
                                  width: 5, // Slightly smaller dot
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getSensorStatusColor(
                                      latestReading!.status,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Grid layout for real-time status items
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildRealTimeItem(
                          'Distance',
                          () {
                            String distanceValue = latestReading != null
                                ? '${latestReading!.distance.toStringAsFixed(2)} cm'
                                : '${currentWaterLevel.toStringAsFixed(2)} cm';
                            debugPrint('=== Distance UI Debug ===');
                            debugPrint(
                              'latestReading != null: ${latestReading != null}',
                            );
                            if (latestReading != null) {
                              debugPrint(
                                'latestReading.distance: ${latestReading!.distance}',
                              );
                              debugPrint(
                                'Raw distance (already in cm): ${latestReading!.distance}',
                              );
                            }
                            debugPrint('currentWaterLevel: $currentWaterLevel');
                            debugPrint(
                              'Final distance display value: $distanceValue',
                            );
                            return distanceValue;
                          }(),
                          Icons.straighten,
                          latestReading != null
                              ? Colors.green
                              : _getStatusColor(status),
                        ),
                        _buildRealTimeItem(
                          'Water Level',
                          () {
                            String waterValue = latestReading != null
                                ? '${latestReading!.waterLevel}%'
                                : 'N/A';
                            debugPrint('=== Water Level UI Debug ===');
                            debugPrint(
                              'latestReading != null: ${latestReading != null}',
                            );
                            if (latestReading != null) {
                              debugPrint(
                                'latestReading.waterLevel: ${latestReading!.waterLevel}',
                              );
                            }
                            debugPrint(
                              'Final water level display value: $waterValue',
                            );
                            return waterValue;
                          }(),
                          Icons.water,
                          Colors.blue[600]!,
                        ),
                        _buildRealTimeItem(
                          'Sensor Status',
                          () {
                            String statusValue = latestReading != null
                                ? latestReading!.status.toUpperCase()
                                : 'No Data';
                            debugPrint('=== Sensor Status UI Debug ===');
                            debugPrint(
                              'latestReading != null: ${latestReading != null}',
                            );
                            if (latestReading != null) {
                              debugPrint(
                                'latestReading.status: "${latestReading!.status}"',
                              );
                              debugPrint(
                                'latestReading.status.toUpperCase(): "${latestReading!.status.toUpperCase()}"',
                              );
                            }
                            debugPrint(
                              'Final status display value: $statusValue',
                            );
                            return statusValue;
                          }(),
                          Icons.sensors,
                          latestReading != null
                              ? _getSensorStatusColor(latestReading!.status)
                              : Colors.grey[600]!,
                        ),
                        _buildRealTimeItem(
                          'Updated',
                          () {
                            String timeValue = _getLastUpdateTime();
                            // Add timestamp for better visibility
                            if (lastUpdateTime != null) {
                              final seconds = lastUpdateTime!.second;
                              timeValue += ' (${seconds}s)';
                            }
                            return timeValue;
                          }(),
                          Icons.access_time,
                          latestReading != null
                              ? Colors.blue
                              : Colors.grey[600]!,
                        ),
                        _buildRealTimeItem(
                          'Max Depth',
                          latestReading != null
                              ? '${latestReading!.maxDepth.toStringAsFixed(2)} cm'
                              : 'N/A',
                          Icons.vertical_align_bottom,
                          Colors.purple[600]!,
                        ),
                        _buildRealTimeItem(
                          'Connection',
                          isConnected ? 'LIVE' : 'OFFLINE',
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          isConnected ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Water Level Graph (Inverted: Shows actual water level height)
            // Higher values = higher water level = more dangerous
            SizedBox(
              height: 300,
              child: WaterLevelTrend(
                currentWaterLevel: () {
                  // Invert the chart: show actual water level instead of distance
                  if (latestReading != null) {
                    // Water level = maxDepth - distance (inverted)
                    double actualWaterLevel =
                        latestReading!.maxDepth - latestReading!.distance;
                    debugPrint('=== Chart Water Level Debug ===');
                    debugPrint('maxDepth: ${latestReading!.maxDepth}');
                    debugPrint('distance: ${latestReading!.distance}');
                    debugPrint('actualWaterLevel: $actualWaterLevel');
                    debugPrint(
                      'actualWaterLevel (meters): ${actualWaterLevel / 100.0}',
                    );
                    return actualWaterLevel /
                        100.0; // Convert cm to meters for chart
                  } else {
                    // Fallback: use maxDepth - currentWaterLevel for legacy data
                    double maxDepth =
                        latestReading?.maxDepth ?? 100.0; // Default 100cm
                    double actualWaterLevel = maxDepth - currentWaterLevel;
                    debugPrint('=== Chart Water Level Debug (Fallback) ===');
                    debugPrint('maxDepth: $maxDepth');
                    debugPrint(
                      'currentWaterLevel (distance): $currentWaterLevel',
                    );
                    debugPrint('actualWaterLevel: $actualWaterLevel');
                    return actualWaterLevel / 100.0;
                  }
                }(),
                waterLevelData: waterLevelData.map((spot) {
                  // Invert each data point: maxDepth - distance
                  double maxDepth =
                      latestReading?.maxDepth ?? 100.0; // Default 100cm
                  double actualWaterLevel = maxDepth - spot.y;
                  return FlSpot(
                    spot.x,
                    actualWaterLevel / 100.0,
                  ); // Convert to meters
                }).toList(),
                statusColor: _getStatusColor(status),
                // Invert thresholds to match inverted chart
                // These represent actual water level thresholds now
                normalThreshold: () {
                  double maxDepth = latestReading?.maxDepth ?? 100.0;
                  double invertedNormal = maxDepth - normalThreshold;
                  debugPrint('=== Inverted Threshold Debug ===');
                  debugPrint(
                    'Original normalThreshold (distance): $normalThreshold',
                  );
                  debugPrint('maxDepth: $maxDepth');
                  debugPrint(
                    'Inverted normalThreshold (water level): $invertedNormal',
                  );
                  debugPrint(
                    'Inverted normalThreshold (meters): ${invertedNormal / 100.0}',
                  );
                  return invertedNormal / 100.0; // Convert to meters for chart
                }(),
                warningThreshold: () {
                  double maxDepth = latestReading?.maxDepth ?? 100.0;
                  double invertedWarning = maxDepth - warningThreshold;
                  debugPrint(
                    'Inverted warningThreshold (water level): $invertedWarning',
                  );
                  debugPrint(
                    'Inverted warningThreshold (meters): ${invertedWarning / 100.0}',
                  );
                  return invertedWarning / 100.0; // Convert to meters for chart
                }(),
                dangerThreshold: () {
                  double maxDepth = latestReading?.maxDepth ?? 100.0;
                  double invertedDanger = maxDepth - dangerThreshold;
                  debugPrint(
                    'Inverted dangerThreshold (water level): $invertedDanger',
                  );
                  debugPrint(
                    'Inverted dangerThreshold (meters): ${invertedDanger / 100.0}',
                  );
                  return invertedDanger / 100.0; // Convert to meters for chart
                }(),
                unit: currentUnit,
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
      deviceStatus = null; // Clear device status when disconnected
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
        // Start fetching sensor data from the connected device
        debugPrint('=== Starting Sensor Data Service ===');
        debugPrint(
          'Calling sensorDataService.updateDeviceIp($connectedDeviceIp)',
        );
        sensorDataService.updateDeviceIp(connectedDeviceIp);
        debugPrint('Sensor data service updated with device IP');

        // Verify the data stream is available
        debugPrint(
          'sensorDataService.dataStream != null: ${sensorDataService.dataStream != null}',
        );

        // Re-setup the sensor data listener with the new stream
        _setupSensorDataListener();

        // Fetch initial device status
        _fetchDeviceStatus();
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
        debugPrint('Raw JSON data: ${reading.toString()}');
        debugPrint('Distance: ${reading.distance}');
        debugPrint('Water Level: ${reading.waterLevel}');
        debugPrint('Status: "${reading.status}"');
        debugPrint('Timestamp: ${reading.timestamp}');
        debugPrint('Max Depth: ${reading.maxDepth}');

        // Get status before and after update for comparison
        final oldStatus = latestReading != null ? _getWaterLevelStatus() : null;

        debugPrint('=== Before setState ===');
        debugPrint(
          'Current latestReading: ${latestReading?.toString() ?? 'null'}',
        );
        debugPrint('Current currentWaterLevel: $currentWaterLevel');

        setState(() {
          // Store the complete reading
          latestReading = reading;
          lastUpdateTime = DateTime.now();

          // Use distance as the water level (distance from sensor)
          currentWaterLevel = reading.distance;

          debugPrint('=== Inside setState ===');
          debugPrint('Set latestReading: ${latestReading?.toString()}');
          debugPrint('Set currentWaterLevel: $currentWaterLevel');

          // Add new data point to the chart with proper time indexing
          _addDataPointWithTimestamp(reading.distance, reading.timestamp);
        });

        debugPrint('=== After setState ===');
        debugPrint('Final latestReading: ${latestReading?.toString()}');
        debugPrint('Final currentWaterLevel: $currentWaterLevel');

        // Check new status
        final newStatus = _getWaterLevelStatus();
        debugPrint('Status changed from $oldStatus to $newStatus');

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
        // This just logs the error from the stream
      },
    );

    debugPrint('✅ Sensor data listener setup successful');
  }

  // Add data point to the chart with timestamp
  void _addDataPointWithTimestamp(double waterLevel, int timestamp) {
    double xValue;

    if (waterLevelData.isEmpty) {
      xValue = 0;
    } else {
      // Increment from the last x value
      xValue = waterLevelData.last.x + 1;
    }

    // Keep only the last 24 data points for the chart
    if (waterLevelData.length >= 24) {
      waterLevelData.removeAt(0);
      // Shift x values to maintain sequence
      for (int i = 0; i < waterLevelData.length; i++) {
        waterLevelData[i] = FlSpot(i.toDouble(), waterLevelData[i].y);
      }
      xValue = waterLevelData.length.toDouble();
    }

    waterLevelData.add(FlSpot(xValue, waterLevel));
    debugPrint(
      'Added data point: distance=$waterLevel, timestamp=$timestamp, x=$xValue',
    );
  }

  // Check water level and trigger alerts if needed
  void _checkAndTriggerAlert() {
    final status = _getWaterLevelStatus();

    // Create alert messages based on sensor status or distance
    String alertMessage = 'Water level warning detected';
    String dangerMessage = 'Critical water level detected!';

    if (latestReading != null) {
      String sensorStatus = latestReading!.status.toUpperCase();
      String formattedDistance = latestReading!.distance.toStringAsFixed(2);

      if (sensorStatus == 'MEDIUM') {
        alertMessage =
            'MEDIUM water level detected - Distance: $formattedDistance cm';
      } else if (sensorStatus == 'HIGH') {
        dangerMessage =
            'HIGH water level CRITICAL - Distance: $formattedDistance cm';
      }
    }

    // Trigger notifications based on status
    if (status == WaterLevelStatus.warning) {
      debugPrint('Water Level Warning: $alertMessage');
      _showNotification(
        'Water Level Warning',
        alertMessage,
        soundFileName: 'warning',
      );
    } else if (status == WaterLevelStatus.danger) {
      debugPrint('Water Level Alert: $dangerMessage');
      _showNotification(
        'Water Level Alert',
        dangerMessage,
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
