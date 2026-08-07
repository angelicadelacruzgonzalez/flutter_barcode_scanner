import AVFoundation
import Flutter
import UIKit

/// Entry point of the barcode scanner plugin on iOS.
///
/// Mirrors the Android contract: `scanBarcode` returns a single code through the
/// method channel, `startBarcodeStream` pushes codes to the event channel
/// `flutter_barcode_scanner_update/stream` and `stopBarcodeStream` closes it.
public class SwiftFlutterBarcodeScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private enum Channel {
        static let method = "flutter_barcode_scanner_update"
        static let event = "flutter_barcode_scanner_update/stream"
    }

    private enum ErrorCode {
        static let cancelled = "CANCELLED"
        static let permissionDenied = "PERMISSION_DENIED"
        static let noRootViewController = "NO_ROOT"
        static let alreadyRunning = "ALREADY_RUNNING"
    }

    private enum Method {
        static let scanBarcode = "scanBarcode"
        static let startStream = "startBarcodeStream"
        static let stopStream = "stopBarcodeStream"
    }

    private var eventSink: FlutterEventSink?
    /// Result of a single scan, pending until the scanner reports back.
    private var pendingResult: FlutterResult?
    private weak var scannerViewController: BarcodeScannerViewController?

    // MARK: - FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterBarcodeScannerPlugin()

        let methodChannel = FlutterMethodChannel(
            name: Channel.method,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: Channel.event,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case Method.scanBarcode:
            requestCameraAccess { [weak self] granted in
                guard let self = self else { return }
                guard granted else {
                    result(self.permissionError())
                    return
                }
                self.presentScanner(
                    configuration: ScannerConfiguration(
                        arguments: call.arguments,
                        isContinuousScan: false
                    ),
                    result: result
                )
            }

        case Method.startStream:
            requestCameraAccess { [weak self] granted in
                guard let self = self else { return }
                guard granted else {
                    result(self.permissionError())
                    return
                }
                self.presentScanner(
                    configuration: ScannerConfiguration(
                        arguments: call.arguments,
                        isContinuousScan: true
                    ),
                    result: result
                )
            }

        case Method.stopStream:
            dismissScanner { result(nil) }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Camera permission

    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func permissionError() -> FlutterError {
        FlutterError(
            code: ErrorCode.permissionDenied,
            message: "Camera permission was denied",
            details: nil
        )
    }

    // MARK: - Presentation

    private func presentScanner(
        configuration: ScannerConfiguration,
        result: @escaping FlutterResult
    ) {
        guard scannerViewController == nil else {
            result(FlutterError(
                code: ErrorCode.alreadyRunning,
                message: "A scan is already in progress",
                details: nil
            ))
            return
        }

        guard let presenter = SwiftFlutterBarcodeScannerPlugin.topViewController() else {
            result(FlutterError(
                code: ErrorCode.noRootViewController,
                message: "No view controller available to present the scanner",
                details: nil
            ))
            return
        }

        let controller = BarcodeScannerViewController(configuration: configuration)
        controller.modalPresentationStyle = .fullScreen

        controller.onBarcodeDetected = { [weak self] payload in
            guard let self = self else { return }
            if configuration.isContinuousScan {
                // The stream contract is a Stream<String>, so only the raw value
                // is pushed. Use scanBarcodeWithOptions when metadata is needed.
                self.eventSink?(payload.rawValue)
            } else {
                self.dismissScanner {
                    // Dart maps this dictionary to a BarcodeResult; the legacy
                    // scanBarcode wrapper reads only the rawValue entry.
                    self.deliverPendingResult(payload.dictionary)
                }
            }
        }

        controller.onCancelled = { [weak self] in
            guard let self = self else { return }
            self.dismissScanner {
                if configuration.isContinuousScan {
                    // Matches Android: closing the scanner ends the Dart stream.
                    self.eventSink?(FlutterEndOfEventStream)
                } else {
                    self.deliverPendingResult(FlutterError(
                        code: ErrorCode.cancelled,
                        message: "User cancelled the scan",
                        details: nil
                    ))
                }
            }
        }

        scannerViewController = controller

        if configuration.isContinuousScan {
            // Codes arrive through the event channel, so acknowledge immediately.
            presenter.present(controller, animated: true) { result(nil) }
        } else {
            pendingResult = result
            presenter.present(controller, animated: true, completion: nil)
        }
    }

    private func deliverPendingResult(_ value: Any?) {
        guard let result = pendingResult else { return }
        pendingResult = nil
        result(value)
    }

    private func dismissScanner(completion: @escaping () -> Void) {
        guard let controller = scannerViewController else {
            completion()
            return
        }
        scannerViewController = nil
        controller.dismiss(animated: true, completion: completion)
    }

    /// Finds the top-most view controller without using the deprecated
    /// `UIApplication.keyWindow`.
    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
