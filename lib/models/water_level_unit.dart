enum WaterLevelUnit {
  meters('m', 'Meters', 1.0),
  centimeters('cm', 'Centimeters', 100.0),
  feet('ft', 'Feet', 3.28084),
  inches('in', 'Inches', 39.3701);

  const WaterLevelUnit(this.symbol, this.displayName, this.conversionFactor);

  final String symbol;
  final String displayName;
  final double conversionFactor;

  double fromMeters(double meters) {
    return meters * conversionFactor;
  }

  double toMeters(double value) {
    return value / conversionFactor;
  }

  String formatValue(double value) {
    switch (this) {
      case WaterLevelUnit.meters:
        return value.toStringAsFixed(2);
      case WaterLevelUnit.centimeters:
        return value.toStringAsFixed(0);
      case WaterLevelUnit.feet:
        return value.toStringAsFixed(1);
      case WaterLevelUnit.inches:
        return value.toStringAsFixed(0);
    }
  }

  double getChartInterval() {
    switch (this) {
      case WaterLevelUnit.meters:
        return 1.0; // 1 meter intervals
      case WaterLevelUnit.centimeters:
        return 0.5; // 50 cm intervals (0.5 meters)
      case WaterLevelUnit.feet:
        return 0.6096; // 2 feet intervals (2 * 0.3048)
      case WaterLevelUnit.inches:
        return 0.3048; // 12 inches intervals (12 * 0.0254)
    }
  }

  // Get max value for chart (in the display unit)
  double getChartMaxValue() {
    switch (this) {
      case WaterLevelUnit.meters:
        return 6.0;
      case WaterLevelUnit.centimeters:
        return 600.0; // 600 cm = 6 meters
      case WaterLevelUnit.feet:
        return 20.0;
      case WaterLevelUnit.inches:
        return 240.0;
    }
  }

  // Get appropriate display interval for labels (in display unit)
  double getDisplayInterval() {
    switch (this) {
      case WaterLevelUnit.meters:
        return 1.0; // Every 1 meter
      case WaterLevelUnit.centimeters:
        return 50.0; // Every 50 cm
      case WaterLevelUnit.feet:
        return 2.0; // Every 2 feet
      case WaterLevelUnit.inches:
        return 24.0; // Every 24 inches (2 feet)
    }
  }
}
