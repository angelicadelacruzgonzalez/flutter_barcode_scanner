import UIKit

/// Draws the scanner guidance above the camera preview: a dimmed scrim with a
/// clear scan window, corner brackets and an animated sweep line.
///
/// Detection always runs on the full frame, so the window is visual guidance
/// only. This mirrors the Android overlay so both platforms look the same.
final class ScannerOverlayView: UIView {

    private enum Metrics {
        static let qrWindowSideRatio: CGFloat = 0.68
        static let barcodeWindowWidthRatio: CGFloat = 0.85
        static let barcodeWindowAspectRatio: CGFloat = 0.45
        static let cornerLengthRatio: CGFloat = 0.12
        static let cornerWidth: CGFloat = 3
        static let lineWidth: CGFloat = 2
        static let lineInset: CGFloat = 8
        static let scrimAlpha: CGFloat = 0.6
        static let sweepDuration: TimeInterval = 1.8
        static let bottomBarAllowance: CGFloat = 72
    }

    private let scrimLayer = CAShapeLayer()
    private let cornersLayer = CAShapeLayer()
    private let sweepLineLayer = CAShapeLayer()

    private let scanMode: ScanMode
    private let lineColor: UIColor

    private var scanWindow: CGRect = .zero

    init(scanMode: ScanMode, lineColor: UIColor) {
        self.scanMode = scanMode
        self.lineColor = lineColor
        super.init(frame: .zero)

        backgroundColor = .clear
        isUserInteractionEnabled = false
        setUpLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setUpLayers() {
        scrimLayer.fillColor = UIColor.black.withAlphaComponent(Metrics.scrimAlpha).cgColor
        scrimLayer.fillRule = .evenOdd
        layer.addSublayer(scrimLayer)

        cornersLayer.strokeColor = lineColor.cgColor
        cornersLayer.fillColor = UIColor.clear.cgColor
        cornersLayer.lineWidth = Metrics.cornerWidth
        cornersLayer.lineCap = .round
        layer.addSublayer(cornersLayer)

        sweepLineLayer.strokeColor = lineColor.cgColor
        sweepLineLayer.lineWidth = Metrics.lineWidth
        sweepLineLayer.lineCap = .round
        layer.addSublayer(sweepLineLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scanWindow = calculateScanWindow()
        scrimLayer.frame = bounds
        cornersLayer.frame = bounds
        sweepLineLayer.frame = bounds

        scrimLayer.path = scrimPath()
        cornersLayer.path = cornersPath()
        sweepLineLayer.path = sweepLinePath()

        startSweepAnimation()
    }

    private func calculateScanWindow() -> CGRect {
        // Keep the window vertically centred in the area above the bottom bar.
        let availableHeight = bounds.height - Metrics.bottomBarAllowance
        guard bounds.width > 0, availableHeight > 0 else { return .zero }

        let size: CGSize
        switch scanMode {
        case .barcode:
            let width = bounds.width * Metrics.barcodeWindowWidthRatio
            size = CGSize(width: width, height: width * Metrics.barcodeWindowAspectRatio)
        case .qr, .default:
            let side = min(bounds.width, availableHeight) * Metrics.qrWindowSideRatio
            size = CGSize(width: side, height: side)
        }

        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: (availableHeight - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func scrimPath() -> CGPath {
        let path = UIBezierPath(rect: bounds)
        // The even-odd fill rule punches the scan window out of the scrim.
        path.append(UIBezierPath(rect: scanWindow))
        return path.cgPath
    }

    private func cornersPath() -> CGPath {
        let path = UIBezierPath()
        guard !scanWindow.isEmpty else { return path.cgPath }

        let length = min(scanWindow.width, scanWindow.height) * Metrics.cornerLengthRatio

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // (corner, horizontal end, vertical end)
            (CGPoint(x: scanWindow.minX, y: scanWindow.minY),
             CGPoint(x: scanWindow.minX + length, y: scanWindow.minY),
             CGPoint(x: scanWindow.minX, y: scanWindow.minY + length)),
            (CGPoint(x: scanWindow.maxX, y: scanWindow.minY),
             CGPoint(x: scanWindow.maxX - length, y: scanWindow.minY),
             CGPoint(x: scanWindow.maxX, y: scanWindow.minY + length)),
            (CGPoint(x: scanWindow.minX, y: scanWindow.maxY),
             CGPoint(x: scanWindow.minX + length, y: scanWindow.maxY),
             CGPoint(x: scanWindow.minX, y: scanWindow.maxY - length)),
            (CGPoint(x: scanWindow.maxX, y: scanWindow.maxY),
             CGPoint(x: scanWindow.maxX - length, y: scanWindow.maxY),
             CGPoint(x: scanWindow.maxX, y: scanWindow.maxY - length))
        ]

        for (corner, horizontalEnd, verticalEnd) in corners {
            path.move(to: corner)
            path.addLine(to: horizontalEnd)
            path.move(to: corner)
            path.addLine(to: verticalEnd)
        }

        return path.cgPath
    }

    private func sweepLinePath() -> CGPath {
        let path = UIBezierPath()
        guard !scanWindow.isEmpty else { return path.cgPath }

        path.move(to: CGPoint(x: scanWindow.minX + Metrics.lineInset, y: scanWindow.minY))
        path.addLine(to: CGPoint(x: scanWindow.maxX - Metrics.lineInset, y: scanWindow.minY))
        return path.cgPath
    }

    private func startSweepAnimation() {
        sweepLineLayer.removeAnimation(forKey: "sweep")
        guard !scanWindow.isEmpty else { return }

        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = scanWindow.height
        animation.duration = Metrics.sweepDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        sweepLineLayer.add(animation, forKey: "sweep")
    }
}
