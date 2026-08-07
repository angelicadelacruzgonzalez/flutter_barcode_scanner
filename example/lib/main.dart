import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner_update/flutter_barcode_scanner_update.dart';

void main() => runApp(const BarcodeScannerExampleApp());

class BarcodeScannerExampleApp extends StatelessWidget {
  const BarcodeScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3D8BEF),
      ),
      home: const BarcodeScannerPage(),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  static const String _lineColor = '#3D8BEF';
  static const String _cancelText = 'Cancelar';

  StreamSubscription<String>? _barcodeSubscription;
  bool _isStreaming = false;

  /// Rows shown in the result list. Detailed scans include the metadata.
  final List<String> _log = <String>[];

  void _addLog(String entry) {
    if (!mounted) return;
    setState(() => _log.insert(0, entry));
  }

  /// The original API, unchanged: returns the raw value, or '-1' on cancel.
  Future<void> _scanLegacy(ScanMode mode) async {
    try {
      final String result = await FlutterBarcodeScanner.scanBarcode(
        _lineColor,
        _cancelText,
        false,
        mode,
      );
      if (result == FlutterBarcodeScanner.cancelledResult) {
        _addLog('Cancelado');
        return;
      }
      _addLog('legacy · $result');
    } on PlatformException catch (e) {
      // Real failures now surface instead of being reported as '-1'.
      _addLog('Error ${e.code}: ${e.message}');
    }
  }

  /// The new API: named options, a format filter and the enriched result.
  Future<void> _scanDetailed() async {
    try {
      final BarcodeResult? result =
          await FlutterBarcodeScanner.scanBarcodeWithOptions(
        const ScannerOptions(
          lineColor: _lineColor,
          cancelButtonText: _cancelText,
          isShowFlashIcon: true,
          scanMode: ScanMode.BARCODE,
          // Only retail symbologies: a marketing QR code in frame is ignored.
          formats: <BarcodeFormat>[
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.code128,
            BarcodeFormat.upcA,
          ],
        ),
      );

      if (result == null) {
        _addLog('Cancelado');
        return;
      }

      _addLog(
        '${result.rawValue}\n'
        'formato: ${result.format?.name ?? 'desconocido'} · '
        'tipo: ${result.valueType.name}'
        '${result.displayValue != null ? '\nvisible: ${result.displayValue}' : ''}',
      );
    } on PlatformException catch (e) {
      _addLog('Error ${e.code}: ${e.message}');
    }
  }

  /// Continuous scanning. Only QR codes are accepted here.
  void _startStream() {
    _barcodeSubscription?.cancel();

    final Stream<String> stream =
        FlutterBarcodeScanner.getBarcodeStreamWithOptions(
      const ScannerOptions(
        lineColor: _lineColor,
        cancelButtonText: _cancelText,
        scanMode: ScanMode.QR,
        formats: <BarcodeFormat>[BarcodeFormat.qrCode],
      ),
    );

    _barcodeSubscription = stream.listen(
      (String barcode) => _addLog('stream · $barcode'),
      onError: (Object error) => _addLog('Stream error: $error'),
      // Fired when the scanner screen is dismissed.
      onDone: () {
        if (mounted) setState(() => _isStreaming = false);
      },
    );

    setState(() => _isStreaming = true);
  }

  Future<void> _stopStream() async {
    await _barcodeSubscription?.cancel();
    _barcodeSubscription = null;
    // Cancelling the subscription already closes the camera; this is only
    // needed when the stream is kept alive elsewhere.
    await FlutterBarcodeScanner.stopBarcodeStream();
    if (mounted) setState(() => _isStreaming = false);
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner Update'),
        centerTitle: true,
        actions: <Widget>[
          if (_log.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(_log.clear),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: <Widget>[
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  onPressed: () => _scanLegacy(ScanMode.QR),
                  label: const Text('QR (API previa)'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: _scanDetailed,
                  label: const Text('Retail (con opciones)'),
                ),
                ElevatedButton.icon(
                  icon: Icon(_isStreaming
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded),
                  onPressed: _isStreaming ? _stopStream : _startStream,
                  label: Text(_isStreaming ? 'Detener stream' : 'Stream QR'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _log.isEmpty
                  ? const Center(child: Text('Sin lecturas todavía.'))
                  : ListView.separated(
                      itemCount: _log.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) => ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: Text(_log[index]),
                      ),
                    ),
            ),
            Text(
              'flutter_barcode_scanner_update',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
