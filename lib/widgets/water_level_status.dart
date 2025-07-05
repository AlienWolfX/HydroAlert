import 'package:flutter/material.dart';

enum WaterLevelStatus { normal, warning, danger }

class WaterLevelStatusWidget extends StatelessWidget {
  final WaterLevelStatus currentStatus;

  const WaterLevelStatusWidget({super.key, required this.currentStatus});

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

  IconData _getStatusIcon(WaterLevelStatus status) {
    switch (status) {
      case WaterLevelStatus.normal:
        return Icons.check_circle;
      case WaterLevelStatus.warning:
        return Icons.warning;
      case WaterLevelStatus.danger:
        return Icons.dangerous;
    }
  }

  Widget _buildStatusIndicator(
    String label,
    WaterLevelStatus indicatorStatus,
    WaterLevelStatus currentStatus,
  ) {
    final isActive = indicatorStatus == currentStatus;
    final color = _getStatusColor(indicatorStatus);

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : color.withOpacity(0.3),
            border: Border.all(color: color, width: isActive ? 3 : 1),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            _getStatusIcon(indicatorStatus),
            color: isActive ? Colors.white : color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? color : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Water Level Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusIndicator(
                  'Normal',
                  WaterLevelStatus.normal,
                  currentStatus,
                ),
                _buildStatusIndicator(
                  'Warning',
                  WaterLevelStatus.warning,
                  currentStatus,
                ),
                _buildStatusIndicator(
                  'Danger',
                  WaterLevelStatus.danger,
                  currentStatus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
