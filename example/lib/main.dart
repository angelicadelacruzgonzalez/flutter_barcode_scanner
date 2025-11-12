/* import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner_update/flutter_barcode_scanner_update.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BarcodeScannerPage(),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  String _scanBarcode = 'Unknown';
  Stream<String>? _barcodeStream;

  Future<void> scanQR() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.QR);
      setState(() {
        _scanBarcode = barcodeScanRes;
      });
    } catch (e) {
      setState(() {
        _scanBarcode = 'Error: $e';
      });
    }
  }

  Future<void> scanBarcodeNormal() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.BARCODE);
      setState(() {
        _scanBarcode = barcodeScanRes;
      });
    } catch (e) {
      setState(() {
        _scanBarcode = 'Error: $e';
      });
    }
  }

  void startBarcodeScanStream() {
    _barcodeStream = FlutterBarcodeScanner.getBarcodeStreamReceiver(
        '#ff6666', 'Cancel', true, ScanMode.BARCODE);
    setState(() {}); // refresca para usar StreamBuilder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
                onPressed: scanBarcodeNormal,
                child: const Text('Start barcode scan')),
            ElevatedButton(
                onPressed: scanQR, child: const Text('Start QR scan')),
            ElevatedButton(
                onPressed: startBarcodeScanStream,
                child: const Text('Start barcode scan stream')),
            const SizedBox(height: 20),
            Expanded(
              child: _barcodeStream != null
                  ? StreamBuilder<String>(
                      stream: _barcodeStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: Text('Waiting for scans...'));
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData) {
                          return const Center(child: Text('No scans yet.'));
                        } else {
                          return Center(
                            child: Text(
                              'Scan result: ${snapshot.data}',
                              style: const TextStyle(fontSize: 20),
                            ),
                          );
                        }
                      },
                    )
                  : Center(
                      child: Text(
                        'Scan result: $_scanBarcode',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
 */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner_update/flutter_barcode_scanner_update.dart';

void main() => runApp(const BarcodeScannerExampleApp());

class BarcodeScannerExampleApp extends StatelessWidget {
  const BarcodeScannerExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF007AFF),
        brightness: Brightness.light,
      ),
      home: const BarcodeScannerPage(),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  StreamSubscription<String>? _barcodeSubscription;

  bool _isStreaming = false;
  int _scanLimit = 5;
  final List<String> _scannedCodes = [];

  /// 🔹 Escaneo único (QR o código de barras)
  Future<void> scanSingle(ScanMode mode) async {
    try {
      final result = await FlutterBarcodeScanner.scanBarcode(
        '#007AFF',
        'Cancel',
        true,
        mode,
      );
      if (!mounted || result == '-1') return;
      setState(() {
        _scannedCodes.add(result);
      });
    } catch (e) {
      setState(() => _scannedCodes.add('Error: $e'));
    }
  }

  /// 🔹 Escaneo continuo con límite configurable
  Future<void> startBarcodeScanStream() async {
    try {
      _barcodeSubscription?.cancel();
      _scannedCodes.clear();

      final stream = FlutterBarcodeScanner.getBarcodeStreamReceiver(
        '#007AFF',
        'Cancel',
        true,
        ScanMode.BARCODE,
      );

      if (stream == null) {
        setState(
            () => _scannedCodes.add('Error: No se pudo iniciar el stream.'));
        return;
      }

      _barcodeSubscription = stream.listen((barcode) {
        if (barcode == '-1') return;

        if (!_scannedCodes.contains(barcode)) {
          setState(() {
            _scannedCodes.add(barcode);
          });
        }

        debugPrint('Código leído: $barcode');

        if (_scannedCodes.length >= _scanLimit) {
          stopBarcodeScanStream(showDialogOnFinish: true);
        }
      }, onError: (error) {
        debugPrint('Error en stream: $error');
        setState(() => _scannedCodes.add('Stream error: $error'));
      });

      setState(() => _isStreaming = true);
    } catch (e) {
      setState(() => _scannedCodes.add('Error: $e'));
    }
  }

  /// 🔹 Detiene el escaneo continuo
  void stopBarcodeScanStream({bool showDialogOnFinish = false}) {
    _barcodeSubscription?.cancel();
    setState(() => _isStreaming = false);

    if (showDialogOnFinish && _scannedCodes.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Escaneo completo'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: _scannedCodes
                    .map((code) => ListTile(
                          leading: const Icon(Icons.qr_code_2),
                          title: Text(code),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  clearScans();
                },
                child: const Text('Limpiar lista'),
              ),
            ],
          ),
        );
      });
    }
  }

  /// 🔹 Copiar lista al portapapeles
  Future<void> copyToClipboard() async {
    if (_scannedCodes.isEmpty) return;
    final text = _scannedCodes.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Códigos copiados al portapapeles'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 🔹 Limpia la lista de resultados
  void clearScans() {
    setState(() => _scannedCodes.clear());
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResults = _scannedCodes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner Update'),
        centerTitle: true,
        elevation: 1,
        actions: [
          if (hasResults)
            IconButton(
              tooltip: 'Copiar lista',
              icon: const Icon(Icons.copy_all_rounded),
              onPressed: copyToClipboard,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 120,
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
            const SizedBox(height: 20),
            Text(
              'Lectura continua (${_scanLimit} códigos máx.)',
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Slider(
              value: _scanLimit.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_scanLimit',
              onChanged: !_isStreaming
                  ? (v) => setState(() => _scanLimit = v.toInt())
                  : null,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: hasResults
                  ? ListView.separated(
                      itemCount: _scannedCodes.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: theme.colorScheme.outlineVariant),
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: Text(
                          _scannedCodes[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'No hay códigos escaneados aún.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  onPressed: () => scanSingle(ScanMode.QR),
                  label: const Text('Scan QR'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () => scanSingle(ScanMode.BARCODE),
                  label: const Text('Scan Barcode'),
                ),
                ElevatedButton.icon(
                  icon: Icon(_isStreaming
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded),
                  onPressed: _isStreaming
                      ? () => stopBarcodeScanStream(showDialogOnFinish: true)
                      : startBarcodeScanStream,
                  label: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreaming
                        ? Colors.redAccent
                        : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (hasResults && !_isStreaming)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: clearScans,
                    label: const Text('Clear Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceTint,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Powered by flutter_barcode_scanner_update',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
