import AVFoundation
import MLKitBarcodeScanning
import MLKitVision
import UIKit

/// Full screen scanner backed by AVFoundation and ML Kit.
///
/// Honours every option exposed by the Dart API: `lineColor` and `scanMode`
/// drive the overlay, `cancelButtonText` labels the dismiss button and
/// `isShowFlashIcon` shows or hides the torch toggle.
final class BarcodeScannerViewController: UIViewController {

    /// Called for every detected code. In single scan mode it fires at most once.
    var onBarcodeDetected: ((BarcodePayload) -> Void)?
    /// Called when the user dismisses the scanner.
    var onCancelled: (() -> Void)?

    private enum Metrics {
        static let bottomBarHeight: CGFloat = 72
        static let buttonSize: CGFloat = 44
        static let horizontalMargin: CGFloat = 16
        /// The same code is ignored while this window is open, so a code held in
        /// front of the camera is not emitted on every frame.
        static let duplicateWindow: TimeInterval = 1.5
    }

    private let configuration: ScannerConfiguration

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "flutter_barcode_scanner_update.session")
    private let videoQueue = DispatchQueue(label: "flutter_barcode_scanner_update.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)

    private var captureDevice: AVCaptureDevice?
    private lazy var barcodeScanner: BarcodeScanner = {
        BarcodeScanner.barcodeScanner(
            options: BarcodeScannerOptions(formats: configuration.formats)
        )
    }()

    private lazy var overlayView = ScannerOverlayView(
        scanMode: configuration.scanMode,
        lineColor: configuration.lineColor
    )
    private let bottomBar = UIView()
    private let flashButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private var isProcessingFrame = false
    private var hasDeliveredResult = false
    private var isTorchOn = false
    private var lastBarcode: String?
    private var lastBarcodeAt: Date?

    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setUpPreview()
        setUpOverlay()
        setUpBottomBar()

        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(on: false)
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        updateVideoOrientation()
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    // MARK: - UI

    private func setUpPreview() {
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }

    private func setUpOverlay() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setUpBottomBar() {
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = configuration.lineColor
        flashButton.isHidden = !configuration.isShowFlashIcon
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(handleFlashTapped), for: .touchUpInside)
        bottomBar.addSubview(flashButton)

        cancelButton.setTitle(configuration.cancelButtonText, for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
        bottomBar.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -Metrics.bottomBarHeight
            ),

            flashButton.leadingAnchor.constraint(
                equalTo: bottomBar.leadingAnchor,
                constant: Metrics.horizontalMargin
            ),
            flashButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            flashButton.widthAnchor.constraint(equalToConstant: Metrics.buttonSize),
            flashButton.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),

            cancelButton.trailingAnchor.constraint(
                equalTo: bottomBar.trailingAnchor,
                constant: -Metrics.horizontalMargin
            ),
            cancelButton.centerYAnchor.constraint(equalTo: flashButton.centerYAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: Metrics.buttonSize)
        ])
    }

    // MARK: - Session

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.handleCancelTapped()
            }
            return
        }

        captureDevice = device
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            self?.updateVideoOrientation()
        }
        session.startRunning()
    }

    /// Keeps the preview and the delivered frames aligned with the interface,
    /// which is what makes landscape scanning work.
    private func updateVideoOrientation() {
        guard let videoOrientation = currentVideoOrientation() else { return }
        previewLayer.connection?.videoOrientation = videoOrientation
        videoOutput.connection(with: .video)?.videoOrientation = videoOrientation
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation? {
        let interfaceOrientation: UIInterfaceOrientation?
        if #available(iOS 13.0, *) {
            interfaceOrientation = view.window?.windowScene?.interfaceOrientation
        } else {
            interfaceOrientation = UIApplication.shared.statusBarOrientation
        }

        switch interfaceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }

    // MARK: - Actions

    @objc private func handleCancelTapped() {
        onCancelled?()
    }

    @objc private func handleFlashTapped() {
        setTorch(on: !isTorchOn)
    }

    private func setTorch(on: Bool) {
        guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else {
            flashButton.isEnabled = false
            flashButton.alpha = 0.4
            return
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = on
            flashButton.setImage(
                UIImage(systemName: on ? "bolt.fill" : "bolt.slash.fill"),
                for: .normal
            )
        } catch {
            // Torch is best effort: keep scanning if it cannot be configured.
        }
    }

    // MARK: - Detection

    private func handle(payload: BarcodePayload) {
        if configuration.isContinuousScan {
            guard !isDuplicate(payload.rawValue) else { return }
            onBarcodeDetected?(payload)
        } else {
            guard !hasDeliveredResult else { return }
            hasDeliveredResult = true
            onBarcodeDetected?(payload)
        }
    }

    private func isDuplicate(_ value: String) -> Bool {
        let now = Date()
        if value == lastBarcode,
           let previous = lastBarcodeAt,
           now.timeIntervalSince(previous) < Metrics.duplicateWindow {
            return true
        }
        lastBarcode = value
        lastBarcodeAt = now
        return false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BarcodeScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Drop frames while a detection is in flight so the queue never backs up.
        guard !isProcessingFrame, !hasDeliveredResult else { return }
        isProcessingFrame = true

        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = imageOrientation()

        barcodeScanner.process(visionImage) { [weak self] barcodes, error in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }

            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else { return }

            guard let payload = barcodes.lazy
                .compactMap({ BarcodePayload(barcode: $0) })
                .first else { return }

            DispatchQueue.main.async {
                self.handle(payload: payload)
            }
        }
    }

    /// The connection already rotates the frames to match the interface, so the
    /// buffer is upright and only the mirroring of the front camera matters.
    private func imageOrientation() -> UIImage.Orientation {
        let isFrontCamera = captureDevice?.position == .front
        return isFrontCamera ? .leftMirrored : .up
    }
}
