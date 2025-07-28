class SensorReading {
  final double distance;
  final int waterLevel;
  final String status;
  final int timestamp;
  final double maxDepth;

  SensorReading({
    required this.distance,
    required this.waterLevel,
    required this.status,
    required this.timestamp,
    required this.maxDepth,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      distance: (json['distance'] as num).toDouble(),
      waterLevel: json['waterLevel'] as int,
      status: json['status'] as String,
      timestamp: json['timestamp'] as int,
      maxDepth: (json['maxDepth'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'waterLevel': waterLevel,
      'status': status,
      'timestamp': timestamp,
      'maxDepth': maxDepth,
    };
  }

  @override
  String toString() {
    return 'SensorReading(distance: $distance, waterLevel: $waterLevel, status: $status, timestamp: $timestamp, maxDepth: $maxDepth)';
  }
}
