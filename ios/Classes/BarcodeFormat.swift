import Vision

/// Mirrors `com.google.mlkit.vision.barcode.common.Barcode`'s format constants,
/// which is what Dart's `formats` bitmask is built from on both platforms. iOS
/// no longer depends on ML Kit for scanning, but it still has to speak the same
/// integer language as Android so `BarcodeResult.fromMap` behaves identically
/// regardless of platform.
struct BarcodeFormat: OptionSet {
    let rawValue: Int

    static let unknown = BarcodeFormat(rawValue: 0)
    static let code128 = BarcodeFormat(rawValue: 0x0001)
    static let code39 = BarcodeFormat(rawValue: 0x0002)
    static let code93 = BarcodeFormat(rawValue: 0x0004)
    static let codabar = BarcodeFormat(rawValue: 0x0008)
    static let dataMatrix = BarcodeFormat(rawValue: 0x0010)
    static let ean13 = BarcodeFormat(rawValue: 0x0020)
    static let ean8 = BarcodeFormat(rawValue: 0x0040)
    static let itf = BarcodeFormat(rawValue: 0x0080)
    static let qrCode = BarcodeFormat(rawValue: 0x0100)
    static let upcA = BarcodeFormat(rawValue: 0x0200)
    static let upcE = BarcodeFormat(rawValue: 0x0400)
    static let pdf417 = BarcodeFormat(rawValue: 0x0800)
    static let aztec = BarcodeFormat(rawValue: 0x1000)

    static let all: BarcodeFormat = [
        .code128, .code39, .code93, .codabar, .dataMatrix, .ean13, .ean8,
        .itf, .qrCode, .upcA, .upcE, .pdf417, .aztec
    ]
}

extension BarcodeFormat {

    /// Vision symbologies to request from `VNDetectBarcodesRequest` for this
    /// mask. Some symbologies only exist from iOS 15 onward; those are skipped
    /// on older systems rather than crashing.
    var visionSymbologies: [VNBarcodeSymbology] {
        var symbologies: [VNBarcodeSymbology] = []

        if contains(.code128) { symbologies.append(.code128) }
        if contains(.code39) {
            symbologies.append(contentsOf: [
                .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum
            ])
        }
        if contains(.code93) { symbologies.append(contentsOf: [.code93, .code93i]) }
        if contains(.codabar), #available(iOS 15.0, *) { symbologies.append(.codabar) }
        if contains(.dataMatrix) { symbologies.append(.dataMatrix) }
        if contains(.itf) {
            symbologies.append(contentsOf: [.itf14, .i2of5, .i2of5Checksum])
        }
        if contains(.qrCode) {
            symbologies.append(.qr)
            if #available(iOS 15.0, *) { symbologies.append(.microQR) }
        }
        if contains(.upcE) { symbologies.append(.upce) }
        if contains(.pdf417) {
            symbologies.append(.pdf417)
            if #available(iOS 15.0, *) { symbologies.append(.microPDF417) }
        }
        if contains(.aztec) { symbologies.append(.aztec) }

        // Vision has no distinct UPC-A symbology: UPC-A codes surface as EAN-13
        // with a leading zero. Request EAN-13 whenever either format is wanted,
        // and let `BarcodeFormat.from(_:payload:)` sort the payload back into
        // upcA vs ean13 for the value handed to Dart.
        if contains(.ean13) || contains(.upcA), !symbologies.contains(.ean13) {
            symbologies.append(.ean13)
        }
        if contains(.ean8) { symbologies.append(.ean8) }

        return symbologies
    }

    /// Maps a detected symbology (plus its payload, to disambiguate UPC-A from
    /// EAN-13) back onto the ML Kit-compatible constant Dart expects.
    static func from(_ symbology: VNBarcodeSymbology, payload: String) -> Int {
        if #available(iOS 15.0, *) {
            switch symbology {
            case .codabar: return BarcodeFormat.codabar.rawValue
            case .microQR: return BarcodeFormat.qrCode.rawValue
            case .microPDF417: return BarcodeFormat.pdf417.rawValue
            default: break
            }
        }

        switch symbology {
        case .code128:
            return BarcodeFormat.code128.rawValue
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            return BarcodeFormat.code39.rawValue
        case .code93, .code93i:
            return BarcodeFormat.code93.rawValue
        case .dataMatrix:
            return BarcodeFormat.dataMatrix.rawValue
        case .ean13:
            // UPC-A is EAN-13 with a leading "0" in Vision's model.
            if payload.count == 13, payload.hasPrefix("0") {
                return BarcodeFormat.upcA.rawValue
            }
            return BarcodeFormat.ean13.rawValue
        case .ean8:
            return BarcodeFormat.ean8.rawValue
        case .itf14, .i2of5, .i2of5Checksum:
            return BarcodeFormat.itf.rawValue
        case .qr:
            return BarcodeFormat.qrCode.rawValue
        case .upce:
            return BarcodeFormat.upcE.rawValue
        case .pdf417:
            return BarcodeFormat.pdf417.rawValue
        case .aztec:
            return BarcodeFormat.aztec.rawValue
        default:
            return BarcodeFormat.unknown.rawValue
        }
    }
}

/// Mirrors `Barcode.BarcodeValueType` from ML Kit. Vision does not classify
/// payloads the way ML Kit does, so this is a best-effort heuristic based on
/// common QR code payload prefixes (vCard, WiFi, mailto, tel, geo, ...).
///
/// KNOWN LIMITATION vs. the ML Kit-backed implementation: ML Kit also breaks
/// structured payloads into typed fields (e.g. individual vCard fields, WiFi
/// SSID/password). This heuristic only classifies the *kind* of payload; it
/// does not parse the fields within it.
enum BarcodeValueType {
    static let unknown = 0
    static let contactInfo = 1
    static let email = 2
    static let isbn = 3
    static let phone = 4
    static let product = 5
    static let sms = 6
    static let text = 7
    static let url = 8
    static let wifi = 9
    static let geographicCoordinates = 10
    static let calendarEvent = 11
    static let driverLicense = 12

    static func infer(from rawValue: String) -> Int {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = value.lowercased()

        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return url
        }
        if lowercased.hasPrefix("wifi:") {
            return wifi
        }
        if lowercased.hasPrefix("mailto:") {
            return email
        }
        if lowercased.hasPrefix("tel:") {
            return phone
        }
        if lowercased.hasPrefix("smsto:") || lowercased.hasPrefix("sms:") {
            return sms
        }
        if lowercased.hasPrefix("geo:") {
            return geographicCoordinates
        }
        if lowercased.hasPrefix("begin:vcard") {
            return contactInfo
        }
        if lowercased.hasPrefix("begin:vevent") {
            return calendarEvent
        }
        return text
    }
}
