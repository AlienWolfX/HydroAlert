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
  double currentWaterLevel = 0; 
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
  
  List<String> availableDevices = [];
  String? selectedDeviceIp;
  bool showDeviceSelector = false;
  
  DateTime? lastWarningAlert;
  DateTime? lastDangerAlert;
  static const Duration alertCooldown = Duration(minutes: 5);

  int connectionRetries = 0;
  static const int maxRetries = 3;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  double normalThreshold = 5.0;
  double warningThreshold = 3.5;
  double dangerThreshold = 2.0;

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

  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      normalThreshold = prefs.getDouble('normalThreshold') ?? 5.0;
      warningThreshold = prefs.getDouble('warningThreshold') ?? 3.5;
      dangerThreshold = prefs.getDouble('dangerThreshold') ?? 2.0;
    });
  }

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

    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
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
    String channelId;
    if (soundFileName == 'danger') {
      channelId = 'hydroalert_danger';
    } else if (soundFileName == 'warning') {
      channelId = 'hydroalert_warning';
    } else {
      channelId = 'hydroalert_warning'; 
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
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
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
      
      double distance = latestReading!.distance;
      if (distance >= normalThreshold) {
        return WaterLevelStatus.normal;
      } else if (distance >= warningThreshold) {
        return WaterLevelStatus.warning;
      } else if (distance >= dangerThreshold) {
        return WaterLevelStatus.danger;
      }
      
      if (latestReading!.waterLevel <= 30) {
        return WaterLevelStatus.normal;
      } else if (latestReading!.waterLevel <= 70) {
        return WaterLevelStatus.warning;
      } else {
        return WaterLevelStatus.danger;
      }
    }

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
      padding: const EdgeInsets.all(8), 
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, 
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(6), 
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: isHighlighted ? 20 : 18,
            ),
          ),
          const SizedBox(height: 4), 
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10, 
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isHighlighted ? 12 : 11,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.2,
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _debugSoundFiles() {
    debugPrint('Testing notification sounds...');
    debugPrint(
      'Warning sound file should be in: android/app/src/main/res/raw/warning',
    );
    debugPrint(
      'Danger sound file should be in: android/app/src/main/res/raw/danger',
    );
  }

  void _updateThresholds(double normal, double warning, double danger) {
    setState(() {
      normalThreshold = normal;
      warningThreshold = warning;
      dangerThreshold = danger;
    });
    _saveThresholds(); 
  }

  void _showDeviceSelectorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
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
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.devices,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Multiple Devices Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${availableDevices.length} HydroAlert devices on the network:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                ...availableDevices.map((deviceIp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).pop();
                          _connectToDevice(deviceIp);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.router,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HydroAlert Device',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      deviceIp,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Rescan'),
              onPressed: () {
                Navigator.of(context).pop();
                _manualRescan();
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  showDeviceSelector = false;
                  availableDevices.clear();
                });
                // Retry scan after dismissing
                Future.delayed(const Duration(seconds: 5), () {
                  if (!isConnected) {
                    _scanForDevice();
                  }
                });
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

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
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wifi,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Connected to $connectedDeviceIp',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (availableDevices.length > 1) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.devices,
                                    color: Colors.blue[600],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${availableDevices.length} devices available',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _showDeviceSelectorDialog();
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                    child: Text(
                                      'Switch',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
              child: Text(
                'HydroAlert',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.blue[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
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
                    : showDeviceSelector
                    ? Colors.blue
                    : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color:
                        (isScanning
                                ? Colors.orange
                                : isConnected
                                ? Colors.green
                                : showDeviceSelector
                                ? Colors.blue
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
            if (availableDevices.length > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${availableDevices.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
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
                padding: const EdgeInsets.all(16), 
                child: Column(
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (isConnected
                                        ? _getStatusColor(status)
                                        : Colors.grey[400]!)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isConnected
                                ? Icons.water_drop
                                : Icons.water_drop_outlined,
                            color: isConnected
                                ? _getStatusColor(status)
                                : Colors.grey[400]!,
                            size: 24, 
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, 
                            children: [
                              Text(
                                isConnected
                                    ? 'Real-time Status'
                                    : 'Offline Status',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w700,
                                  color: isConnected
                                      ? Colors.blue[800]
                                      : Colors.grey[600],
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), 
                              Row(
                                children: [
                                  if (isConnected) ...[
                                    Flexible(
                                      child: Text(
                                        'Last updated: ${_getLastUpdateTime()}',
                                        style: TextStyle(
                                          fontSize: 11, // Reduced font size
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else ...[
                                    Flexible(
                                      child: Text(
                                        'No device connected',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red[600],
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4), 
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
                                  if (availableDevices.length > 1) ...[
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.swap_horiz,
                                          size: 14,
                                          color: Colors.orange[600],
                                        ),
                                        onPressed: () => _showDeviceSelectorDialog(),
                                        tooltip: 'Switch Device (${availableDevices.length} available)',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ), 
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isConnected
                                          ? _getStatusColor(status)
                                          : Colors.grey[400]!)
                                      .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isConnected
                                    ? _getStatusColor(status)
                                    : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    isConnected
                                        ? _getStatusText(status)
                                        : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isConnected
                                          ? _getStatusColor(status)
                                          : Colors.grey[600]!,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (latestReading != null && isConnected) ...[
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
                            if (!isConnected) {
                              return 'No Data';
                            }
                            String distanceValue = latestReading != null
                                ? '${latestReading!.distance.toStringAsFixed(1)} cm'
                                : '${currentWaterLevel.toStringAsFixed(1)} cm';
                            return distanceValue;
                          }(),
                          Icons.straighten,
                          isConnected && latestReading != null
                              ? _getStatusColor(status)
                              : Colors.grey[600]!,
                          isHighlighted:
                              isConnected && status == WaterLevelStatus.danger,
                        ),
                        _buildRealTimeItem(
                          'Water Level',
                          () {
                            if (!isConnected) {
                              return 'No Data';
                            }
                            String waterValue = latestReading != null
                                ? '${latestReading!.waterLevel}%'
                                : 'N/A';
                            return waterValue;
                          }(),
                          Icons.water,
                          isConnected ? Colors.blue[600]! : Colors.grey[600]!,
                          isHighlighted:
                              isConnected && 
                              latestReading != null &&
                              latestReading!.waterLevel > 70,
                        ),
                        _buildRealTimeItem(
                          'Sensor Status',
                          () {
                            if (!isConnected) {
                              return 'No Data';
                            }
                            String statusValue = latestReading != null
                                ? latestReading!.status.toUpperCase()
                                : 'No Data';
                            return statusValue;
                          }(),
                          Icons.sensors,
                          isConnected && latestReading != null
                              ? _getSensorStatusColor(latestReading!.status)
                              : Colors.grey[600]!,
                          isHighlighted:
                              isConnected &&
                              latestReading != null &&
                              [
                                'HIGH',
                                'MEDIUM',
                              ].contains(latestReading!.status.toUpperCase()),
                        ),
                        _buildRealTimeItem(
                          'Max Depth',
                          () {
                            if (!isConnected) {
                              return 'No Data';
                            }
                            return latestReading != null
                                ? '${latestReading!.maxDepth.toStringAsFixed(1)} cm'
                                : 'N/A';
                          }(),
                          Icons.vertical_align_bottom,
                          isConnected ? Colors.purple[600]! : Colors.grey[600]!,
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

            SizedBox(
              height: 400,
              child: WaterLevelTrend(
                currentWaterLevel:
                    latestReading?.waterLevel.toDouble() ??
                    0.0, 
                waterLevelData:
                    waterLevelData,
                statusColor: _getStatusColor(status),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _startNetworkScanning() {
    _scanForDevice();
  }

  void _onSensorConnectionLost() {
    debugPrint('Sensor connection lost, restarting network scan...');
    setState(() {
      isConnected = false;
      connectedDeviceIp = null;
      selectedDeviceIp = null;
      deviceStatus = null; 
      lastDeviceStatusUpdate = null;
      showDeviceSelector = false;
      availableDevices.clear();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!isConnected) {
        _scanForDevice();
      }
    });
  }

  Future<void> _scanForDevice() async {
    if (isScanning || (isConnected && selectedDeviceIp != null)) {
      return;
    }

    setState(() {
      isScanning = true;
    });

    try {
      final List<String> foundDevices = [];
      
      final singleDevice = await networkScanner.scanNetwork();
      if (singleDevice != null) {
        foundDevices.add(singleDevice);
        // Simulate additional devices for demonstration (remove in production)
        // foundDevices.add('192.168.1.101');
        // foundDevices.add('192.168.1.102');
      }
      
      setState(() {
        availableDevices = foundDevices;
        isScanning = false;
      });

      if (foundDevices.isNotEmpty) {
        debugPrint('Found ${foundDevices.length} device(s): $foundDevices');
        
        if (foundDevices.length == 1) {
          // Single device found - connect automatically
          final deviceIp = foundDevices.first;
          await _connectToDevice(deviceIp);
        } else {
          // Multiple devices found - show selector
          setState(() {
            showDeviceSelector = true;
          });
          _showDeviceSelectorDialog();
        }
        
        connectionRetries = 0; 
      } else {
        debugPrint('No devices found on port 65500');
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
    } catch (e) {
      debugPrint('Network scan error: $e');
      setState(() {
        isConnected = false;
        connectedDeviceIp = null;
        selectedDeviceIp = null;
        isScanning = false;
        availableDevices.clear();
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

  Future<void> _manualRescan() async {
    setState(() {
      isConnected = false;
      connectedDeviceIp = null;
      selectedDeviceIp = null;
      availableDevices.clear();
      showDeviceSelector = false;
    });
    
    sensorDataSubscription?.cancel();
    sensorDataSubscription = null;
    
    _scanForDevice();
  }

  Future<void> _connectToDevice(String deviceIp) async {
    debugPrint('Connecting to device: $deviceIp');
    
    setState(() {
      isConnected = true;
      connectedDeviceIp = deviceIp;
      selectedDeviceIp = deviceIp;
      showDeviceSelector = false;
    });

    sensorDataService.updateDeviceIp(deviceIp);
    _setupSensorDataListener();
    _fetchDeviceStatus();
  }

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
    }
  }

  void _setupSensorDataListener() {
    debugPrint('=== Setting up sensor data listener ===');

    sensorDataSubscription?.cancel();
    sensorDataSubscription = null;

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

        final oldStatus = latestReading != null ? _getWaterLevelStatus() : null;

        setState(() {
          latestReading = reading;
          lastUpdateTime = DateTime.now();

          currentWaterLevel = reading.distance;

          _addDataPointWithTimestamp(reading.distance, reading.timestamp);
        });

        final newStatus = _getWaterLevelStatus();
        if (oldStatus != newStatus) {
          debugPrint('Status changed from $oldStatus to $newStatus');
        }

        _checkAndTriggerAlert();

        final now = DateTime.now();
        if (lastDeviceStatusUpdate == null ||
            now.difference(lastDeviceStatusUpdate!).inSeconds >= 30) {
          _fetchDeviceStatus();
          lastDeviceStatusUpdate = now;
        }
      },
      onError: (error) {
        debugPrint('Sensor data stream error: $error');
      },
    );

    debugPrint('✅ Sensor data listener setup successful');
  }

  void _addDataPointWithTimestamp(double distance, int timestamp) {
    double waterLevelPercent = latestReading?.waterLevel.toDouble() ?? 0.0;

    double chartValue = waterLevelPercent;
    chartValue = chartValue.clamp(0.0, 100.0); 

    double xValue = waterLevelData.length.toDouble();

    if (waterLevelData.length >= 24) {
      waterLevelData.removeAt(0);
  
      for (int i = 0; i < waterLevelData.length; i++) {
        waterLevelData[i] = FlSpot(i.toDouble(), waterLevelData[i].y);
      }
  
      xValue = waterLevelData.length.toDouble();
    }

    waterLevelData.add(FlSpot(xValue, chartValue));

    debugPrint(
      'Added data point: waterLevel=$waterLevelPercent%, chartValue=$chartValue, x=$xValue, total points=${waterLevelData.length}',
    );
  }

  void _checkAndTriggerAlert() {
    final status = _getWaterLevelStatus();
    final now = DateTime.now();

    String alertMessage = 'Water level warning detected';
    String dangerMessage = 'Critical water level detected!';

    if (latestReading != null) {
      String sensorStatus = latestReading!.status.toUpperCase();
      String formattedDistance = latestReading!.distance.toStringAsFixed(1);

      if (sensorStatus == 'MEDIUM') {
        alertMessage =
            'MEDIUM water level detected - Distance: $formattedDistance cm';
      } else if (sensorStatus == 'HIGH') {
        dangerMessage =
            'HIGH water level CRITICAL - Distance: $formattedDistance cm';
      }
    }

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
