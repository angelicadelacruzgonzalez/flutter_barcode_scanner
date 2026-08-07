import 'barcode_format.dart';

/// Overlay graphics shown by the native scanner.
///
/// The value only controls the shape of the scan window drawn on screen. To
/// restrict which symbologies are accepted use [ScannerOptions.formats].
///
/// [DEFAULT] is intentionally declared last so the indices of [QR] and
/// [BARCODE] stay unchanged for apps built against previous versions.
enum ScanMode { QR, BARCODE, DEFAULT }

/// Options accepted by `FlutterBarcodeScanner.scanBarcodeWithOptions`.
///
/// Every field has a default, so only the options that matter need to be
/// supplied. The legacy positional API maps onto this class internally.
class ScannerOptions {
  const ScannerOptions({
    this.lineColor = defaultLineColor,
    this.cancelButtonText = defaultCancelButtonText,
    this.isShowFlashIcon = true,
    this.scanMode = ScanMode.QR,
    this.formats = const <BarcodeFormat>[],
  });

  static const String defaultLineColor = '#DC143C';
  static const String defaultCancelButtonText = 'Cancel';

  /// Colour of the sweep line and the window brackets.
  ///
  /// Accepts `#RGB`, `#RRGGBB` and `#AARRGGBB`, with or without the leading
  /// `#`. A malformed value falls back to [defaultLineColor].
  final String lineColor;

  /// Label of the button that dismisses the scanner.
  final String cancelButtonText;

  /// Whether the torch toggle is shown. Hidden automatically on devices without
  /// a flash unit.
  final bool isShowFlashIcon;

  /// Shape of the guidance window drawn over the preview.
  final ScanMode scanMode;

  /// Symbologies to accept. An empty list accepts every supported format.
  ///
  /// Restricting this is the most effective way to avoid reading the wrong code
  /// when several are visible at once, for instance a shelf label next to a
  /// marketing QR code.
  final List<BarcodeFormat> formats;

  /// Serialises the options for the method channel.
  Map<String, dynamic> toArguments({required bool isContinuousScan}) {
    final trimmedColor = lineColor.trim();
    final trimmedCancelText = cancelButtonText.trim();

    return <String, dynamic>{
      'lineColor': trimmedColor.isEmpty ? defaultLineColor : trimmedColor,
      'cancelButtonText':
          trimmedCancelText.isEmpty ? defaultCancelButtonText : trimmedCancelText,
      'isShowFlashIcon': isShowFlashIcon,
      'isContinuousScan': isContinuousScan,
      'scanMode': scanMode.index,
      'formats': BarcodeFormat.toBitmask(formats),
    };
  }

  /// Returns a copy with the given fields replaced.
  ScannerOptions copyWith({
    String? lineColor,
    String? cancelButtonText,
    bool? isShowFlashIcon,
    ScanMode? scanMode,
    List<BarcodeFormat>? formats,
  }) {
    return ScannerOptions(
      lineColor: lineColor ?? this.lineColor,
      cancelButtonText: cancelButtonText ?? this.cancelButtonText,
      isShowFlashIcon: isShowFlashIcon ?? this.isShowFlashIcon,
      scanMode: scanMode ?? this.scanMode,
      formats: formats ?? this.formats,
    );
  }
}
