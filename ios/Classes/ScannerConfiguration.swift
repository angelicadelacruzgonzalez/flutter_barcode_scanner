import UIKit
import Vision

/// Overlay graphics requested by the caller. The raw values match the index
/// order of the Dart `ScanMode` enum.
enum ScanMode: Int {
    case qr = 0
    case barcode = 1
    case `default` = 2

    init(rawIndex: Int?) {
        self = ScanMode(rawValue: rawIndex ?? 0) ?? .qr
    }
}

/// Options forwarded from Dart to the native scanner screen.
struct ScannerConfiguration {

    static let defaultLineColor = "#DC143C"
    static let defaultCancelButtonText = "Cancel"

    let lineColor: UIColor
    let cancelButtonText: String
    let isShowFlashIcon: Bool
    let isContinuousScan: Bool
    let scanMode: ScanMode

    /// Symbologies to accept. Restricting the set speeds up detection and avoids
    /// reading an unrelated code that happens to be in frame. `BarcodeFormat` is
    /// our own ML Kit-compatible bitmask (see BarcodeFormat.swift), translated
    /// to Vision's `VNBarcodeSymbology` at the call site.
    let formats: BarcodeFormat

    init(arguments: Any?, isContinuousScan: Bool) {
        let map = arguments as? [String: Any] ?? [:]

        lineColor = UIColor(hex: map["lineColor"] as? String)
            ?? UIColor(hex: ScannerConfiguration.defaultLineColor)
            ?? .systemRed

        let text = (map["cancelButtonText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelButtonText = (text?.isEmpty == false)
            ? text!
            : ScannerConfiguration.defaultCancelButtonText

        isShowFlashIcon = map["isShowFlashIcon"] as? Bool ?? true
        scanMode = ScanMode(rawIndex: map["scanMode"] as? Int)

        // Dart sends a bitmask built from the ML Kit constants, which are the
        // same on both platforms, so it maps straight onto BarcodeFormat.
        let formatsMask = map["formats"] as? Int ?? 0
        formats = formatsMask == 0 ? .all : BarcodeFormat(rawValue: formatsMask)

        self.isContinuousScan = isContinuousScan
    }
}

extension UIColor {

    /// Parses `#RGB`, `#RRGGBB` and `#AARRGGBB`, with or without the leading `#`.
    /// Returns `nil` when the value cannot be parsed, so a malformed color from
    /// Dart never breaks the scanner.
    convenience init?(hex: String?) {
        guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
            return nil
        }

        var value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        if value.count == 3 {
            // Expand #RGB to #RRGGBB.
            value = value.map { "\($0)\($0)" }.joined()
        }

        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else {
            return nil
        }

        let alpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if value.count == 8 {
            alpha = CGFloat((number & 0xFF00_0000) >> 24) / 255
            red = CGFloat((number & 0x00FF_0000) >> 16) / 255
            green = CGFloat((number & 0x0000_FF00) >> 8) / 255
            blue = CGFloat(number & 0x0000_00FF) / 255
        } else {
            alpha = 1
            red = CGFloat((number & 0xFF0000) >> 16) / 255
            green = CGFloat((number & 0x00FF00) >> 8) / 255
            blue = CGFloat(number & 0x0000FF) / 255
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
