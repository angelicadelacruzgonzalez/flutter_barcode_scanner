import 'dart:async';
import 'package:flutter/services.dart';

enum ScanMode { QR, BARCODE }

class FlutterBarcodeScanner {
  static const MethodChannel _channel =
      MethodChannel('flutter_barcode_scanner_update');

  /// Escaneo único
  static Future<String> scanBarcode(String lineColor, String cancelButtonText,
      bool isShowFlashIcon, ScanMode scanMode) async {
    final String barcode = await _channel.invokeMethod('scanBarcode', {
      'lineColor': lineColor,
      'cancelButtonText': cancelButtonText,
      'isShowFlashIcon': isShowFlashIcon,
      'scanMode': scanMode.index,
    });
    return barcode;
  }

  /// Escaneo continuo con stream
  static Stream<String> getBarcodeStreamReceiver(String lineColor,
      String cancelButtonText, bool isShowFlashIcon, ScanMode scanMode) {
    EventChannel _eventChannel =
        EventChannel('flutter_barcode_scanner_update/stream');
    _channel.invokeMethod('startBarcodeStream', {
      'lineColor': lineColor,
      'cancelButtonText': cancelButtonText,
      'isShowFlashIcon': isShowFlashIcon,
      'scanMode': scanMode.index,
    });
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as String);
  }
}
