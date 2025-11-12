import 'dart:async';
import 'package:flutter/services.dart';

enum ScanMode { QR, BARCODE }

class FlutterBarcodeScanner {
  static const MethodChannel _channel =
      MethodChannel('flutter_barcode_scanner_update');

  /// Escaneo único
/*   static Future<String> scanBarcode(String lineColor, String cancelButtonText,
      bool isShowFlashIcon, ScanMode scanMode) async {
    final String barcode = await _channel.invokeMethod('scanBarcode', {
      'lineColor': lineColor,
      'cancelButtonText': cancelButtonText,
      'isShowFlashIcon': isShowFlashIcon,
      'scanMode': scanMode.index,
    });
    return barcode;
  }
 */

  static Future<String> scanBarcode(
    String lineColor,
    String cancelButtonText,
    bool isShowFlashIcon,
    ScanMode scanMode,
  ) async {
    if (cancelButtonText.isEmpty) {
      cancelButtonText = 'Cancel';
    }

    // Parámetros para el canal nativo
    final Map<String, dynamic> params = {
      'lineColor': lineColor,
      'cancelButtonText': cancelButtonText,
      'isShowFlashIcon': isShowFlashIcon,
      'isContinuousScan': false,
      'scanMode': scanMode.index,
    };

    try {
      final result = await _channel.invokeMethod('scanBarcode', params);

      // Si el plugin devuelve null o el valor de cancelación "-1"
      if (result == null || result == '-1') {
        return '-1'; // o return '-1'; si prefieres mantener el código de cancelación
      }

      return result.toString();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        // Usuario canceló el escaneo
        return '-1'; // o '-1'
      } else {
        // Otro error del canal nativo

        return '-1';
      }
    } catch (e) {
      // Error inesperado

      return '-1';
    }
  }

  static const EventChannel _eventChannel =
      EventChannel('flutter_barcode_scanner_update/stream');

  static Stream<String>? _onBarcodeReceiver;

  /// Escaneo continuo con stream
  static Stream<String> getBarcodeStreamReceiver(
    String lineColor,
    String cancelButtonText,
    bool isShowFlashIcon,
    ScanMode scanMode,
  ) {
    if (cancelButtonText.isEmpty) {
      cancelButtonText = 'Cancel';
    }

    final Map<String, dynamic> params = {
      'lineColor': lineColor,
      'cancelButtonText': cancelButtonText,
      'isShowFlashIcon': isShowFlashIcon,
      'isContinuousScan': true, // 🔁 Importante para escaneo continuo
      'scanMode': scanMode.index,
    };

    // Invoca el método nativo
    _channel.invokeMethod('scanBarcode', params);

    // Reutiliza el stream existente si ya está creado
    _onBarcodeReceiver ??= _eventChannel.receiveBroadcastStream().map((event) {
      return event as String;
    });

    return _onBarcodeReceiver!;
  }
}
