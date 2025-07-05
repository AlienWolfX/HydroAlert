import 'package:flutter/material.dart';
import 'settings_dialog.dart';
import 'about_dialog.dart';
import '../models/water_level_unit.dart';

class HydroAlertDrawer extends StatelessWidget {
  final double normalThreshold;
  final double warningThreshold;
  final double dangerThreshold;
  final WaterLevelUnit currentUnit;
  final Function(double, double, double)? onThresholdsChanged;
  final Function(WaterLevelUnit)? onUnitChanged;

  const HydroAlertDrawer({
    super.key,
    required this.normalThreshold,
    required this.warningThreshold,
    required this.dangerThreshold,
    required this.currentUnit,
    this.onThresholdsChanged,
    this.onUnitChanged,
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
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext context) => HydroAlertSettingsDialog(
                  normalThreshold: normalThreshold,
                  warningThreshold: warningThreshold,
                  dangerThreshold: dangerThreshold,
                  currentUnit: currentUnit,
                  onThresholdsChanged: onThresholdsChanged,
                  onUnitChanged: onUnitChanged,
                ),
              );
            },
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
