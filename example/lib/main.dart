import 'package:flutter/material.dart';
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
