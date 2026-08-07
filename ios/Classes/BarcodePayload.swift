import MLKitBarcodeScanning

/// The data reported for a detected code: raw value plus the metadata ML Kit
/// already computed.
///
/// `dictionary` produces exactly the map consumed by `BarcodeResult.fromMap` on
/// the Dart side, so both platforms answer `scanBarcode` with the same shape.
struct BarcodePayload {

    let rawValue: String
    let displayValue: String?
    let format: Int
    let valueType: Int

    /// Returns `nil` when the code carries no usable raw value.
    init?(barcode: Barcode) {
        guard let rawValue = barcode.rawValue, !rawValue.isEmpty else {
            return nil
        }
        self.rawValue = rawValue
        displayValue = barcode.displayValue
        format = barcode.format.rawValue
        valueType = barcode.valueType.rawValue
    }

    /// Uses a non-optional value type and omits `displayValue` when absent, so no
    /// `Optional.none` is handed to the platform channel codec.
    var dictionary: [String: Any] {
        var map: [String: Any] = [
            "rawValue": rawValue,
            "format": format,
            "valueType": valueType
        ]
        if let displayValue = displayValue, !displayValue.isEmpty {
            map["displayValue"] = displayValue
        }
        return map
    }
}
