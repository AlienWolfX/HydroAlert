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
    deviceIp = ip;
    if (ip != null) {
      _startPeriodicFetch();
    } else {
      _stopPeriodicFetch();
    }
  }

  void _startPeriodicFetch() {
    _stopPeriodicFetch();

    _dataController ??= StreamController<SensorReading>.broadcast();

    _fetchSensorData();

    _fetchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchSensorData();
    });
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return SensorReading.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to fetch sensor data: HTTP ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Request timeout: Device not responding');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response: $e');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> _fetchSensorData() async {
    try {
      final reading = await fetchSensorData();
      if (reading != null &&
          _dataController != null &&
          !_dataController!.isClosed) {
        _dataController!.add(reading);
      }
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');

      if (onConnectionLost != null) {
        onConnectionLost!();
      }

      _stopPeriodicFetch();

      if (_dataController != null && !_dataController!.isClosed) {
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
