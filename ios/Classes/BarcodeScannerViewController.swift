import AVFoundation
import Vision
import UIKit

final class BarcodeScannerViewController: UIViewController {

    var onBarcodeDetected: ((BarcodePayload) -> Void)?
    var onCancelled: (() -> Void)?

    private enum Metrics {
        static let bottomBarHeight: CGFloat = 72
        static let buttonSize: CGFloat = 44
        static let horizontalMargin: CGFloat = 16
        static let duplicateWindow: TimeInterval = 1.5
    }

    private let configuration: ScannerConfiguration

    private let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(
        label: "flutter_barcode_scanner_update.session",
        qos: .userInitiated
    )

    private let videoQueue = DispatchQueue(
        label: "flutter_barcode_scanner_update.video",
        qos: .userInitiated
    )

    private let videoOutput = AVCaptureVideoDataOutput()

    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private var captureDevice: AVCaptureDevice?

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

    private var isSessionConfigured = false

    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .fullScreen
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
            guard let self else { return }

            guard self.isSessionConfigured else {
                return
            }

            guard !self.session.isRunning else {
                return
            }

            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        setTorch(on: false)

        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer.frame = view.bounds

        updateVideoOrientation()
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .all
    }

    // MARK: - UI

    private func setUpPreview() {
        previewLayer.frame = view.bounds

        view.layer.insertSublayer(
            previewLayer,
            at: 0
        )
    }

    private func setUpOverlay() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            overlayView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            overlayView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            overlayView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    private func setUpBottomBar() {
        bottomBar.backgroundColor =
            UIColor.black.withAlphaComponent(0.72)

        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bottomBar)

        flashButton.setImage(
            UIImage(systemName: "bolt.slash.fill"),
            for: .normal
        )

        flashButton.tintColor = configuration.lineColor

        flashButton.isHidden =
            !configuration.isShowFlashIcon

        flashButton.translatesAutoresizingMaskIntoConstraints = false

        flashButton.addTarget(
            self,
            action: #selector(handleFlashTapped),
            for: .touchUpInside
        )

        bottomBar.addSubview(flashButton)

        cancelButton.setTitle(
            configuration.cancelButtonText,
            for: .normal
        )

        cancelButton.setTitleColor(
            .white,
            for: .normal
        )

        cancelButton.titleLabel?.font =
            .systemFont(
                ofSize: 17,
                weight: .medium
            )

        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.addTarget(
            self,
            action: #selector(handleCancelTapped),
            for: .touchUpInside
        )

        bottomBar.addSubview(cancelButton)

        NSLayoutConstraint.activate([

            bottomBar.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            bottomBar.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            bottomBar.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),

            bottomBar.heightAnchor.constraint(
                equalToConstant: Metrics.bottomBarHeight
            ),

            flashButton.leadingAnchor.constraint(
                equalTo: bottomBar.leadingAnchor,
                constant: Metrics.horizontalMargin
            ),

            flashButton.centerYAnchor.constraint(
                equalTo: bottomBar.centerYAnchor
            ),

            flashButton.widthAnchor.constraint(
                equalToConstant: Metrics.buttonSize
            ),

            flashButton.heightAnchor.constraint(
                equalToConstant: Metrics.buttonSize
            ),

            cancelButton.trailingAnchor.constraint(
                equalTo: bottomBar.trailingAnchor,
                constant: -Metrics.horizontalMargin
            ),

            cancelButton.centerYAnchor.constraint(
                equalTo: bottomBar.centerYAnchor
            ),

            cancelButton.heightAnchor.constraint(
                equalToConstant: Metrics.buttonSize
            )
        ])
    }

    // MARK: - AVCaptureSession

    private func configureSession() {

        guard !isSessionConfigured else {
            return
        }

        session.beginConfiguration()

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            session.commitConfiguration()

            notifyScannerError()

            return
        }

        captureDevice = device

        do {

            let input = try AVCaptureDeviceInput(
                device: device
            )

            guard session.canAddInput(input) else {
                session.commitConfiguration()

                notifyScannerError()

                return
            }

            session.addInput(input)

        } catch {
            session.commitConfiguration()

            notifyScannerError()

            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]

        videoOutput.setSampleBufferDelegate(
            self,
            queue: videoQueue
        )

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()

            notifyScannerError()

            return
        }

        session.addOutput(videoOutput)

        session.commitConfiguration()

        isSessionConfigured = true

        DispatchQueue.main.async { [weak self] in
            self?.updateVideoOrientation()
        }

        if !session.isRunning {
            session.startRunning()
        }
    }

    private func notifyScannerError() {
        DispatchQueue.main.async { [weak self] in
            self?.onCancelled?()
        }
    }

    // MARK: - Orientation

    private func updateVideoOrientation() {

        guard let orientation = currentVideoOrientation() else {
            return
        }

        if let connection = previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }

        if let connection = videoOutput.connection(
            with: .video
        ),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }

    private func currentVideoOrientation()
        -> AVCaptureVideoOrientation? {

        let orientation: UIInterfaceOrientation?

        if #available(iOS 13.0, *) {
            orientation =
                view.window?
                    .windowScene?
                    .interfaceOrientation
        } else {
            orientation =
                UIApplication.shared.statusBarOrientation
        }

        switch orientation {
        case .portrait:
            return .portrait

        case .portraitUpsideDown:
            return .portraitUpsideDown

        case .landscapeLeft:
            return .landscapeLeft

        case .landscapeRight:
            return .landscapeRight

        default:
            return nil
        }
    }

    // MARK: - Actions

    @objc
    private func handleCancelTapped() {
        stopCapture()
        onCancelled?()
    }

    @objc
    private func handleFlashTapped() {
        setTorch(on: !isTorchOn)
    }

    // MARK: - Torch

    private func setTorch(on: Bool) {

        guard let device = captureDevice,
              device.hasTorch,
              device.isTorchAvailable else {

            DispatchQueue.main.async { [weak self] in
                self?.flashButton.isEnabled = false
                self?.flashButton.alpha = 0.4
            }

            return
        }

        do {

            try device.lockForConfiguration()

            device.torchMode = on ? .on : .off

            device.unlockForConfiguration()

            isTorchOn = on

            DispatchQueue.main.async { [weak self] in

                self?.flashButton.setImage(
                    UIImage(
                        systemName: on
                            ? "bolt.fill"
                            : "bolt.slash.fill"
                    ),
                    for: .normal
                )
            }

        } catch {
            // Torch is optional.
        }
    }

    // MARK: - Capture

    private func stopCapture() {

        if isTorchOn {
            setTorch(on: false)
        }

        sessionQueue.async { [weak self] in

            guard let self else {
                return
            }

            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    // MARK: - Barcode

    private func handle(
        payload: BarcodePayload
    ) {

        if configuration.isContinuousScan {

            guard !isDuplicate(
                payload.rawValue
            ) else {
                return
            }

            onBarcodeDetected?(payload)

        } else {

            guard !hasDeliveredResult else {
                return
            }

            hasDeliveredResult = true

            stopCapture()

            onBarcodeDetected?(payload)
        }
    }

    private func isDuplicate(
        _ value: String
    ) -> Bool {

        let now = Date()

        if value == lastBarcode,
           let previous = lastBarcodeAt,
           now.timeIntervalSince(previous)
                < Metrics.duplicateWindow {

            return true
        }

        lastBarcode = value
        lastBarcodeAt = now

        return false
    }
}

// MARK: - Vision

extension BarcodeScannerViewController:
    AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        guard !isProcessingFrame else {
            return
        }

        guard !hasDeliveredResult else {
            return
        }

        guard let pixelBuffer =
            CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        isProcessingFrame = true

        let request = VNDetectBarcodesRequest {
            [weak self] request, error in

            guard let self else {
                return
            }

            defer {
                self.isProcessingFrame = false
            }

            guard error == nil else {
                return
            }

            guard let observations =
                request.results as? [VNBarcodeObservation] else {
                return
            }

            guard let observation =
                observations.first(where: {
                    guard let value = $0.payloadStringValue else {
                        return false
                    }

                    return !value.isEmpty
                }) else {
                return
            }

            guard let payload =
                self.makePayload(
                    from: observation
                ) else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.handle(payload: payload)
            }
        }

        request.symbologies =
            visionSymbologies()

        let orientation =
            cgImagePropertyOrientation()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            isProcessingFrame = false
        }
    }

    // MARK: Vision Formats

    private func visionSymbologies()
        -> [VNBarcodeSymbology] {

        var result: [VNBarcodeSymbology] = []

        if #available(iOS 15.0, *) {

            result = [
                .aztec,
                .codabar,
                .code39,
                .code39Checksum,
                .code93,
                .code93i,
                .code128,
                .dataMatrix,
                .ean8,
                .ean13,
                .gs1DataBar,
                .gs1DataBarExpanded,
                .gs1DataBarLimited,
                .itf14,
                .microPDF417,
                .microQR,
                .pdf417,
                .qr,
                .upce
            ]

        } else {

            result = [
                .aztec,
                .code39,
                .code93,
                .code128,
                .dataMatrix,
                .ean8,
                .ean13,
                .itf14,
                .pdf417,
                .qr,
                .upce
            ]
        }

        return result
    }

    // MARK: Payload

private func makePayload(
    from observation: VNBarcodeObservation
) -> BarcodePayload? {
    return BarcodePayload(
        observation: observation
    )
}

    // MARK: Orientation

    private func cgImagePropertyOrientation()
        -> CGImagePropertyOrientation {

        let orientation =
            currentVideoOrientation()

        let isFrontCamera =
            captureDevice?.position == .front

        if isFrontCamera {

            switch orientation {

            case .portrait:
                return .leftMirrored

            case .portraitUpsideDown:
                return .rightMirrored

            case .landscapeLeft:
                return .downMirrored

            case .landscapeRight:
                return .upMirrored

            default:
                return .leftMirrored
            }

        } else {

            switch orientation {

            case .portrait:
                return .right

            case .portraitUpsideDown:
                return .left

            case .landscapeLeft:
                return .up

            case .landscapeRight:
                return .down

            default:
                return .right
            }
        }
    }
}