import 'dart:async';

import 'package:flutter/services.dart';

import 'src/barcode_result.dart';
import 'src/scanner_options.dart';

export 'src/barcode_format.dart' show BarcodeFormat, BarcodeValueType;
export 'src/barcode_result.dart' show BarcodeResult;
export 'src/scanner_options.dart' show ScanMode, ScannerOptions;

/// Barcode and QR code scanner backed by ML Kit (CameraX on Android,
/// AVFoundation on iOS).
class FlutterBarcodeScanner {
  FlutterBarcodeScanner._();

  static const MethodChannel _channel =
      MethodChannel('flutter_barcode_scanner_update');

  static const EventChannel _eventChannel =
      EventChannel('flutter_barcode_scanner_update/stream');

  /// Value returned by [scanBarcode] when the user dismisses the scanner.
  static const String cancelledResult = '-1';

  /// Error code reported by the native side when the user cancels the scan.
  static const String _cancelledCode = 'CANCELLED';

  /// Opens the scanner and returns the first code found, with its metadata.
  ///
  /// Returns `null` when the user dismisses the scanner. Genuine failures such
  /// as a denied camera permission throw a [PlatformException], so they can be
  /// told apart from a cancellation.
  ///
  /// ```dart
  /// final result = await FlutterBarcodeScanner.scanBarcodeWithOptions(
  ///   const ScannerOptions(
  ///     lineColor: '#3D8BEF',
  ///     cancelButtonText: 'Cancelar',
  ///     isShowFlashIcon: false,
  ///     scanMode: ScanMode.BARCODE,
  ///     formats: [BarcodeFormat.ean13, BarcodeFormat.code128],
  ///   ),
  /// );
  /// if (result != null) {
  ///   print('${result.rawValue} (${result.format?.name})');
  /// }
  /// ```
  static Future<BarcodeResult?> scanBarcodeWithOptions(
    ScannerOptions options,
  ) async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>(
        'scanBarcode',
        options.toArguments(isContinuousScan: false),
      );
      return BarcodeResult.fromMap(payload);
    } on PlatformException catch (e) {
      if (e.code == _cancelledCode) {
        return null;
      }
      rethrow;
    }
  }

  /// Opens the scanner, returns the raw value of the first code found and closes
  /// the camera.
  ///
  /// Returns [cancelledResult] (`'-1'`) when the user dismisses the scanner.
  ///
  /// Kept for backwards compatibility: it is a thin wrapper around
  /// [scanBarcodeWithOptions], which also exposes the detected format and
  /// content type.
  static Future<String> scanBarcode(
    String lineColor,
    String cancelButtonText,
    bool isShowFlashIcon,
    ScanMode scanMode,
  ) async {
    final BarcodeResult? result = await scanBarcodeWithOptions(
      ScannerOptions(
        lineColor: lineColor,
        cancelButtonText: cancelButtonText,
        isShowFlashIcon: isShowFlashIcon,
        scanMode: scanMode,
      ),
    );
    return result?.rawValue ?? cancelledResult;
  }

  /// Opens the scanner and emits every code found without closing the camera.
  ///
  /// The camera is started when the returned stream gets its first listener and
  /// is closed automatically once the last subscription is cancelled. Call
  /// [stopBarcodeStream] to close it explicitly.
  static Stream<String> getBarcodeStreamReceiver(
    String lineColor,
    String cancelButtonText,
    bool isShowFlashIcon,
    ScanMode scanMode,
  ) {
    return getBarcodeStreamWithOptions(
      ScannerOptions(
        lineColor: lineColor,
        cancelButtonText: cancelButtonText,
        isShowFlashIcon: isShowFlashIcon,
        scanMode: scanMode,
      ),
    );
  }

  /// Same as [getBarcodeStreamReceiver] but accepting named options, including
  /// a [ScannerOptions.formats] filter.
  ///
  /// Emits raw values. Use [scanBarcodeWithOptions] when the format or content
  /// type of each code is needed.
  static Stream<String> getBarcodeStreamWithOptions(ScannerOptions options) {
    final Map<String, dynamic> arguments =
        options.toArguments(isContinuousScan: true);

    late final StreamController<String> controller;
    StreamSubscription<dynamic>? nativeSubscription;

    controller = StreamController<String>.broadcast(
      onListen: () {
        // Subscribe before starting the camera so no code emitted during
        // start-up is lost.
        nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is String && event.isNotEmpty) {
              controller.add(event);
            }
          },
          onError: controller.addError,
          // The native side ends the stream when the scanner screen is closed,
          // for instance when the user taps the cancel button.
          onDone: controller.close,
        );

        _channel.invokeMethod<void>('startBarcodeStream', arguments).catchError(
          (Object error, StackTrace stackTrace) {
            controller.addError(error, stackTrace);
          },
        );
      },
      onCancel: () async {
        await nativeSubscription?.cancel();
        nativeSubscription = null;
        await stopBarcodeStream();
      },
    );

    return controller.stream;
  }

  /// Closes the scanner opened by [getBarcodeStreamReceiver].
  ///
  /// Safe to call when no scanner is running.
  static Future<void> stopBarcodeStream() {
    return _channel.invokeMethod<void>('stopBarcodeStream');
  }
}
