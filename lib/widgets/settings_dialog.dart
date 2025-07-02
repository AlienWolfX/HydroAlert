import 'package:flutter/material.dart';

class HydroAlertSettingsDialog extends StatelessWidget {
  final double normalThreshold;
  final double warningThreshold;
  final double dangerThreshold;

  const HydroAlertSettingsDialog({
    super.key,
    required this.normalThreshold,
    required this.warningThreshold,
    required this.dangerThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Water Level Thresholds',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildThresholdSetting('Normal Threshold', normalThreshold, 'm'),
            _buildThresholdSetting('Warning Threshold', warningThreshold, 'm'),
            _buildThresholdSetting('Danger Threshold', dangerThreshold, 'm'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildThresholdSetting(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Static method to show the settings dialog
  static void show(
    BuildContext context, {
    required double normalThreshold,
    required double warningThreshold,
    required double dangerThreshold,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) => HydroAlertSettingsDialog(
        normalThreshold: normalThreshold,
        warningThreshold: warningThreshold,
        dangerThreshold: dangerThreshold,
      ),
    );
  }
}
