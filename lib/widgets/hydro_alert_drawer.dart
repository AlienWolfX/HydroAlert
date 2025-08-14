import 'package:flutter/material.dart';
import 'about_dialog.dart';

class HydroAlertDrawer extends StatelessWidget {
  final double normalThreshold;
  final double warningThreshold;
  final double dangerThreshold;
  final Function(double, double, double)? onThresholdsChanged;

  const HydroAlertDrawer({
    super.key,
    required this.normalThreshold,
    required this.warningThreshold,
    required this.dangerThreshold,
    this.onThresholdsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.water_drop, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'HydroAlert',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Water Level Monitoring',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              HydroAlertAboutDialog.show(context);
            },
          ),
        ],
      ),
    );
  }
}
