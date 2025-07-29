class DeviceStatus {
  final String device;
  final String version;
  final String iconsVersion;
  final int uptime;

  DeviceStatus({
    required this.device,
    required this.version,
    required this.iconsVersion,
    required this.uptime,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      device: json['device'] as String,
      version: json['version'] as String,
      iconsVersion: json['iconsVersion'] as String,
      uptime: json['uptime'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device': device,
      'version': version,
      'iconsVersion': iconsVersion,
      'uptime': uptime,
    };
  }

  @override
  String toString() {
    return 'DeviceStatus{device: $device, version: $version, iconsVersion: $iconsVersion, uptime: $uptime}';
  }

  // Helper method to format uptime
  String get formattedUptime {
    int seconds = uptime ~/ 1000; // Convert milliseconds to seconds
    int days = seconds ~/ 86400;
    int hours = (seconds % 86400) ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${remainingSeconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${remainingSeconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }
}
