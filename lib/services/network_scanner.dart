import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkScanner {
  static const int targetPort = 65500;
  static const Duration scanTimeout = Duration(seconds: 2);
  static const Duration connectionTimeout = Duration(seconds: 1);

  String? _connectedDeviceIP;
  bool _isScanning = false;

  String? get connectedDeviceIP => _connectedDeviceIP;
  bool get isScanning => _isScanning;

  /// Scan the local network for devices listening on port 65500
  Future<String?> scanNetwork() async {
    if (_isScanning) return _connectedDeviceIP;

    _isScanning = true;
    debugPrint('Starting network scan for port $targetPort...');

    try {
      // Get the current WiFi IP address
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP == null) {
        debugPrint('No WiFi connection found');
        _isScanning = false;
        return null;
      }

      debugPrint('Current WiFi IP: $wifiIP');

      // Extract network base (e.g., "192.168.1" from "192.168.1.100")
      final parts = wifiIP.split('.');
      if (parts.length != 4) {
        debugPrint('Invalid IP format: $wifiIP');
        _isScanning = false;
        return null;
      }

      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';
      debugPrint('Scanning network: $networkBase.x');

      // Scan the network range (1-254)
      final futures = <Future<String?>>[];

      for (int i = 1; i <= 254; i++) {
        final ip = '$networkBase.$i';
        futures.add(_checkDevice(ip));
      }

      // Wait for all scans to complete or timeout
      final results = await Future.wait(
        futures,
        eagerError: false,
      ).timeout(scanTimeout, onTimeout: () => <String?>[]);

      // Find the first successful connection
      for (final result in results) {
        if (result != null) {
          _connectedDeviceIP = result;
          debugPrint('Device found at: $result');
          _isScanning = false;
          return result;
        }
      }

      debugPrint('No devices found on port $targetPort');
      _connectedDeviceIP = null;
      _isScanning = false;
      return null;
    } catch (e) {
      debugPrint('Network scan error: $e');
      _connectedDeviceIP = null;
      _isScanning = false;
      return null;
    }
  }

  /// Check if a specific IP has a device listening on the target port
  Future<String?> _checkDevice(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        targetPort,
        timeout: connectionTimeout,
      );

      // Successfully connected, close the socket
      await socket.close();
      debugPrint('Found device at $ip:$targetPort');
      return ip;
    } catch (e) {
      // Connection failed - device not found or port not open
      return null;
    }
  }

  /// Verify if the currently connected device is still available
  Future<bool> verifyConnection() async {
    if (_connectedDeviceIP == null) return false;

    final result = await _checkDevice(_connectedDeviceIP!);
    if (result == null) {
      _connectedDeviceIP = null;
      return false;
    }

    return true;
  }

  /// Disconnect from the current device
  void disconnect() {
    _connectedDeviceIP = null;
    debugPrint('Disconnected from device');
  }

  /// Get connection status
  bool get isConnected => _connectedDeviceIP != null;

  /// Get connection info
  String get connectionInfo {
    if (_connectedDeviceIP != null) {
      return 'Connected to $_connectedDeviceIP:$targetPort';
    }
    return 'No device connected';
  }
}
