import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/water_level_unit.dart';

class HydroAlertSettingsDialog extends StatefulWidget {
  final double normalThreshold;
  final double warningThreshold;
  final double dangerThreshold;
  final WaterLevelUnit currentUnit;
  final Function(double, double, double)? onThresholdsChanged;
  final Function(WaterLevelUnit)? onUnitChanged;

  const HydroAlertSettingsDialog({
    super.key,
    required this.normalThreshold,
    required this.warningThreshold,
    required this.dangerThreshold,
    required this.currentUnit,
    this.onThresholdsChanged,
    this.onUnitChanged,
  });

  @override
  State<HydroAlertSettingsDialog> createState() =>
      _HydroAlertSettingsDialogState();
}

class _HydroAlertSettingsDialogState extends State<HydroAlertSettingsDialog> {
  late TextEditingController _normalController;
  late TextEditingController _warningController;
  late TextEditingController _dangerController;
  late WaterLevelUnit _selectedUnit;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.currentUnit;

    // Initialize controllers with values converted to the current unit
    _normalController = TextEditingController(
      text: _selectedUnit.formatValue(
        _selectedUnit.fromMeters(widget.normalThreshold),
      ),
    );
    _warningController = TextEditingController(
      text: _selectedUnit.formatValue(
        _selectedUnit.fromMeters(widget.warningThreshold),
      ),
    );
    _dangerController = TextEditingController(
      text: _selectedUnit.formatValue(
        _selectedUnit.fromMeters(widget.dangerThreshold),
      ),
    );
  }

  @override
  void dispose() {
    _normalController.dispose();
    _warningController.dispose();
    _dangerController.dispose();
    super.dispose();
  }

  String? _validateThreshold(
    String? value,
    String thresholdName, {
    double? minValue,
    double? maxValue,
  }) {
    if (value == null || value.isEmpty) {
      return '$thresholdName is required';
    }

    final doubleValue = double.tryParse(value);
    if (doubleValue == null) {
      return 'Please enter a valid number';
    }

    if (doubleValue < 0) {
      return '$thresholdName must be positive';
    }

    // Convert to meters for validation
    final valueInMeters = _selectedUnit.toMeters(doubleValue);
    final maxInMeters = 10.0; // 10 meters max

    if (valueInMeters > maxInMeters) {
      final maxInCurrentUnit = _selectedUnit.fromMeters(maxInMeters);
      return '$thresholdName must be less than ${_selectedUnit.formatValue(maxInCurrentUnit)} ${_selectedUnit.symbol}';
    }

    if (minValue != null) {
      final minValueInMeters = _selectedUnit.toMeters(minValue);
      if (valueInMeters <= minValueInMeters) {
        return '$thresholdName must be greater than ${_selectedUnit.formatValue(minValue)} ${_selectedUnit.symbol}';
      }
    }

    if (maxValue != null) {
      final maxValueInMeters = _selectedUnit.toMeters(maxValue);
      if (valueInMeters >= maxValueInMeters) {
        return '$thresholdName must be less than ${_selectedUnit.formatValue(maxValue)} ${_selectedUnit.symbol}';
      }
    }

    return null;
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      // Parse values in the current unit and convert to meters
      final normalValue = _selectedUnit.toMeters(
        double.parse(_normalController.text),
      );
      final warningValue = _selectedUnit.toMeters(
        double.parse(_warningController.text),
      );
      final dangerValue = _selectedUnit.toMeters(
        double.parse(_dangerController.text),
      );

      // Additional validation for logical order (descending: Normal > Warning > Danger)
      if (normalValue <= warningValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Normal threshold must be greater than warning threshold (${_selectedUnit.formatValue(_selectedUnit.fromMeters(warningValue))} ${_selectedUnit.symbol})',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (warningValue <= dangerValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning threshold must be greater than danger threshold (${_selectedUnit.formatValue(_selectedUnit.fromMeters(dangerValue))} ${_selectedUnit.symbol})',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save thresholds (in meters) and unit preference
      widget.onThresholdsChanged?.call(normalValue, warningValue, dangerValue);
      widget.onUnitChanged?.call(_selectedUnit);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Water Level Settings'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unit Selection
              const Text(
                'Measurement Unit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<WaterLevelUnit>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Unit',
                ),
                items: WaterLevelUnit.values.map((unit) {
                  return DropdownMenuItem<WaterLevelUnit>(
                    value: unit,
                    child: Text('${unit.displayName} (${unit.symbol})'),
                  );
                }).toList(),
                onChanged: (WaterLevelUnit? newUnit) {
                  if (newUnit != null && newUnit != _selectedUnit) {
                    setState(() {
                      // Convert current values to the new unit
                      final currentNormal = _selectedUnit.toMeters(
                        double.tryParse(_normalController.text) ?? 0,
                      );
                      final currentWarning = _selectedUnit.toMeters(
                        double.tryParse(_warningController.text) ?? 0,
                      );
                      final currentDanger = _selectedUnit.toMeters(
                        double.tryParse(_dangerController.text) ?? 0,
                      );

                      _selectedUnit = newUnit;

                      // Update controllers with converted values
                      _normalController.text = _selectedUnit.formatValue(
                        _selectedUnit.fromMeters(currentNormal),
                      );
                      _warningController.text = _selectedUnit.formatValue(
                        _selectedUnit.fromMeters(currentWarning),
                      );
                      _dangerController.text = _selectedUnit.formatValue(
                        _selectedUnit.fromMeters(currentDanger),
                      );
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Water Level Thresholds (${_selectedUnit.symbol})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Set the water level thresholds for different alert levels:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _buildThresholdField(
                'Normal Threshold',
                _normalController,
                Icons.check_circle,
                Colors.green,
                'Distance above which water level is normal (far from sensor)',
                (value) => _validateThreshold(value, 'Normal threshold'),
              ),

              const SizedBox(height: 16),

              _buildThresholdField(
                'Warning Threshold',
                _warningController,
                Icons.warning,
                Colors.orange,
                'Distance below normal but above danger (water getting closer)',
                (value) => _validateThreshold(
                  value,
                  'Warning threshold',
                  maxValue: double.tryParse(_normalController.text),
                ),
              ),

              const SizedBox(height: 16),

              _buildThresholdField(
                'Danger Threshold',
                _dangerController,
                Icons.dangerous,
                Colors.red,
                'Distance below which water is critical (very close to sensor)',
                (value) => _validateThreshold(
                  value,
                  'Danger threshold',
                  maxValue: double.tryParse(_warningController.text),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Guidelines:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Normal: Distance when water is far from sensor (safe)\n'
                      '• Warning: Distance when water is getting closer (monitor)\n'
                      '• Danger: Distance when water is very close (critical)\n'
                      '• Normal > Warning > Danger (descending distance order)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildThresholdField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
    String hint,
    String? Function(String?) validator,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: _selectedUnit.symbol,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            errorStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
