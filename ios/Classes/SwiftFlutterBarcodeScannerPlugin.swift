import Flutter
import UIKit
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

public class SwiftFlutterBarcodeScannerPlugin: NSObject, FlutterPlugin {
    static var isContinuousScan: Bool = false
    static var result: FlutterResult?
    static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_barcode_scanner_update",
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftFlutterBarcodeScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanBarcode":
            SwiftFlutterBarcodeScannerPlugin.isContinuousScan = false
            SwiftFlutterBarcodeScannerPlugin.result = result
            presentScanner()

        case "startBarcodeStream":
            SwiftFlutterBarcodeScannerPlugin.isContinuousScan = true
            SwiftFlutterBarcodeScannerPlugin.result = result
            presentScanner()

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentScanner() {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
            SwiftFlutterBarcodeScannerPlugin.result?(
                FlutterError(code: "NO_ROOT", message: "No se encontró rootViewController", details: nil)
            )
            SwiftFlutterBarcodeScannerPlugin.result = nil
            return
        }

        let scannerVC = BarcodeScannerViewController()
        scannerVC.isContinuousScan = SwiftFlutterBarcodeScannerPlugin.isContinuousScan
        rootVC.present(scannerVC, animated: true, completion: nil)
    }

    // MARK: - Callback a Flutter
    public static func onBarcodeScanReceiver(barcode: String) {
        if isContinuousScan {
            channel?.invokeMethod("onScanned", arguments: barcode)
        } else {
            result?(barcode)
            result = nil
        }
    }
}
