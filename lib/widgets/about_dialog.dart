import 'package:flutter/material.dart';

class HydroAlertAboutDialog extends StatelessWidget {
  const HydroAlertAboutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About HydroAlert'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'HydroAlert',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Version: 1.0.0', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              'A real-time water level monitoring application that helps track water levels and provides timely alerts for flood prevention.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Developed by Allen Cruiz',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
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

  /// Static method to show the about dialog
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const HydroAlertAboutDialog(),
    );
  }
}
