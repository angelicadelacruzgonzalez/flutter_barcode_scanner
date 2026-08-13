import Vision

/// The data reported for a detected code: raw value plus best-effort metadata.
///
/// `dictionary` produces exactly the map consumed by `BarcodeResult.fromMap` on
/// the Dart side, so both platforms answer `scanBarcode` with the same shape.
///
/// `format` and `valueType` are still ML Kit-compatible integers (see
/// `BarcodeFormat.swift`) even though scanning itself now runs on Apple's
/// Vision framework instead of `MLKitBarcodeScanning`.
struct BarcodePayload {

    let rawValue: String
    let displayValue: String?
    let format: Int
    let valueType: Int

    /// Returns `nil` when the observation carries no usable raw value.
    init?(observation: VNBarcodeObservation) {
        guard let rawValue = observation.payloadStringValue, !rawValue.isEmpty else {
            return nil
        }
        self.rawValue = rawValue
        // Vision doesn't provide a separate human-readable display string the
        // way ML Kit sometimes does, so the raw payload doubles as both.
        displayValue = rawValue
        format = BarcodeFormat.from(observation.symbology, payload: rawValue)
        valueType = BarcodeValueType.infer(from: rawValue)
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
