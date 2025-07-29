import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class SensorDataService {
  static const String apiPath = '/api/readings';
  static const Duration requestTimeout = Duration(seconds: 10);

  String? deviceIp;
  Timer? _fetchTimer;
  StreamController<SensorReading>? _dataController;

  Function()? onConnectionLost;

  Stream<SensorReading>? get dataStream => _dataController?.stream;

  SensorDataService({this.deviceIp, this.onConnectionLost});

  void updateDeviceIp(String? ip) {
    debugPrint('=== SensorDataService.updateDeviceIp ===');
    debugPrint('Old deviceIp: $deviceIp');
    debugPrint('New deviceIp: $ip');

    deviceIp = ip;
    if (ip != null) {
      debugPrint('Starting periodic fetch...');
      _startPeriodicFetch();
    } else {
      debugPrint('Stopping periodic fetch...');
      _stopPeriodicFetch();
    }
  }

  void _startPeriodicFetch() {
    debugPrint('=== _startPeriodicFetch called ===');
    _stopPeriodicFetch();

    debugPrint('Creating stream controller...');
    _dataController ??= StreamController<SensorReading>.broadcast();
    debugPrint('Stream controller created: ${_dataController != null}');

    debugPrint('Starting initial fetch...');
    _fetchSensorData();

    debugPrint('Setting up periodic timer (5 seconds)...');
    _fetchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      debugPrint('=== Periodic fetch triggered ===');
      _fetchSensorData();
    });
    debugPrint('Periodic timer set up: ${_fetchTimer != null}');
  }

  void _stopPeriodicFetch() {
    _fetchTimer?.cancel();
    _fetchTimer = null;
  }

  Future<SensorReading?> fetchSensorData() async {
    if (deviceIp == null) {
      throw Exception('Device IP not set');
    }

    final url = 'http://$deviceIp:65500$apiPath';
    debugPrint('=== HTTP Request Debug ===');
    debugPrint('Attempting to fetch from: $url');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(requestTimeout);

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      debugPrint('Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> jsonData = json.decode(response.body);
          debugPrint('Parsed JSON: $jsonData');

          final sensorReading = SensorReading.fromJson(jsonData);
          debugPrint('Created SensorReading: ${sensorReading.toString()}');

          return sensorReading;
        } catch (e) {
          debugPrint('JSON parsing error: $e');
          debugPrint('Raw response body: ${response.body}');
          throw Exception('JSON parsing failed: $e');
        }
      } else {
        throw Exception(
          'Failed to fetch sensor data: HTTP ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      debugPrint('Request timeout occurred');
      throw Exception('Request timeout: Device not responding');
    } on FormatException catch (e) {
      debugPrint('Format exception: $e');
      throw Exception('Invalid JSON response: $e');
    } catch (e) {
      debugPrint('Network error occurred: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<void> _fetchSensorData() async {
    debugPrint('=== _fetchSensorData called ===');
    try {
      debugPrint('Calling fetchSensorData()...');
      final reading = await fetchSensorData();
      debugPrint(
        'fetchSensorData() returned: ${reading?.toString() ?? 'null'}',
      );

      if (reading != null &&
          _dataController != null &&
          !_dataController!.isClosed) {
        debugPrint('Adding reading to stream...');
        _dataController!.add(reading);
        debugPrint('✅ Reading added to stream successfully');
      } else {
        debugPrint('❌ Cannot add to stream:');
        debugPrint('  reading != null: ${reading != null}');
        debugPrint('  _dataController != null: ${_dataController != null}');
        debugPrint(
          '  !_dataController!.isClosed: ${_dataController != null ? !_dataController!.isClosed : 'N/A'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching sensor data: $e');

      if (onConnectionLost != null) {
        debugPrint('Calling onConnectionLost callback...');
        onConnectionLost!();
      }

      _stopPeriodicFetch();

      if (_dataController != null && !_dataController!.isClosed) {
        debugPrint('Adding error to stream...');
        _dataController!.addError(e);
      }
    }
  }

  void dispose() {
    _stopPeriodicFetch();
    _dataController?.close();
    _dataController = null;
  }
}
