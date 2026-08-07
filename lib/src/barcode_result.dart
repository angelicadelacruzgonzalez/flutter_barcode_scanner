import 'barcode_format.dart';

/// A single code detected by the scanner.
///
/// Returned by `FlutterBarcodeScanner.scanBarcodeWithOptions`. The legacy
/// `scanBarcode` keeps returning only [rawValue] as a `String`.
class BarcodeResult {
  const BarcodeResult({
    required this.rawValue,
    this.displayValue,
    this.format,
    this.valueType = BarcodeValueType.unknown,
  });

  /// The raw content encoded in the barcode, exactly as decoded.
  ///
  /// This is the value the legacy [String] based API returns.
  final String rawValue;

  /// Human readable content when ML Kit can produce one.
  ///
  /// For structured codes it strips protocol prefixes, so a WiFi QR code
  /// exposes the network name instead of the whole `WIFI:` payload. Falls back
  /// to `null` when unavailable.
  final String? displayValue;

  /// The detected symbology, or `null` when the native side reported a format
  /// this plugin does not model.
  final BarcodeFormat? format;

  /// The kind of content ML Kit recognised, such as a URL or a product code.
  final BarcodeValueType valueType;

  /// Builds a result from the map sent over the method channel.
  ///
  /// Returns `null` when the payload carries no usable [rawValue], which is how
  /// a cancelled scan is represented.
  static BarcodeResult? fromMap(Object? payload) {
    if (payload is! Map) {
      return null;
    }

    final rawValue = payload['rawValue'];
    if (rawValue is! String || rawValue.isEmpty) {
      return null;
    }

    final displayValue = payload['displayValue'];
    final format = payload['format'];
    final valueType = payload['valueType'];

    return BarcodeResult(
      rawValue: rawValue,
      displayValue: displayValue is String && displayValue.isNotEmpty
          ? displayValue
          : null,
      format: BarcodeFormat.fromValue(format is int ? format : null),
      valueType: BarcodeValueType.fromValue(valueType is int ? valueType : null),
    );
  }

  @override
  String toString() {
    return 'BarcodeResult(rawValue: $rawValue, displayValue: $displayValue, '
        'format: ${format?.name}, valueType: ${valueType.name})';
  }

  @override
  bool operator ==(Object other) {
    return other is BarcodeResult &&
        other.rawValue == rawValue &&
        other.displayValue == displayValue &&
        other.format == format &&
        other.valueType == valueType;
  }

  @override
  int get hashCode => Object.hash(rawValue, displayValue, format, valueType);
}
