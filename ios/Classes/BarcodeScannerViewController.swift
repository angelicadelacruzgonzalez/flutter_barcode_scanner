import UIKit
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

public class BarcodeScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var barcodeScanner: BarcodeScanner!

    public var isContinuousScan: Bool = false

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCamera()
        setupCloseButton()
        setupMLKitScanner()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Configuración de cámara
    private func setupCamera() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            dismiss(animated: true, completion: nil)
            return
        }
        captureSession.addInput(videoInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "barcodeQueue"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    // MARK: - Botón cerrar
    private func setupCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cerrar", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func closeScanner() {
        dismiss(animated: true) {
            // Devuelve nil como String opcional para evitar error de tipo
            SwiftFlutterBarcodeScannerPlugin.result?(nil as String?)
            SwiftFlutterBarcodeScannerPlugin.result = nil
        }
    }

    // MARK: - Configuración ML Kit
    private func setupMLKitScanner() {
        let options = BarcodeScannerOptions(formats: .all)
        barcodeScanner = BarcodeScanner.barcodeScanner(options: options)
    }

    // MARK: - Procesar frames
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {

        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = .right

        barcodeScanner.process(visionImage) { [weak self] barcodes, error in
            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else { return }
            guard let self = self else { return }

            for barcode in barcodes {
                if let rawValue = barcode.rawValue {
                    DispatchQueue.main.async {
                        if self.isContinuousScan {
                            SwiftFlutterBarcodeScannerPlugin.onBarcodeScanReceiver(barcode: rawValue)
                        } else {
                            self.dismiss(animated: true) {
                                SwiftFlutterBarcodeScannerPlugin.onBarcodeScanReceiver(barcode: rawValue)
                            }
                        }
                    }
                    return
                }
            }
        }
    }
}
