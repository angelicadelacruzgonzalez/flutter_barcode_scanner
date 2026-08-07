/// Barcode symbologies that can be requested through
/// [ScannerOptions.formats].
///
/// The integer values are the ML Kit `Barcode.FORMAT_*` constants and are
/// identical on Android and iOS, which is why they can be sent over the channel
/// as a single bitmask instead of a per-platform mapping table.
enum BarcodeFormat {
  code128(0x0001),
  code39(0x0002),
  code93(0x0004),
  codabar(0x0008),
  dataMatrix(0x0010),
  ean13(0x0020),
  ean8(0x0040),
  itf(0x0080),
  qrCode(0x0100),
  upcA(0x0200),
  upcE(0x0400),
  pdf417(0x0800),
  aztec(0x1000);

  const BarcodeFormat(this.value);

  /// The ML Kit constant backing this format.
  final int value;

  /// Value sent when no filter is applied, meaning every supported format.
  static const int allFormatsValue = 0x0000;

  /// Combines [formats] into the bitmask expected by the native side.
  ///
  /// An empty list yields [allFormatsValue].
  static int toBitmask(Iterable<BarcodeFormat> formats) {
    var mask = allFormatsValue;
    for (final format in formats) {
      mask |= format.value;
    }
    return mask;
  }

  /// Resolves the format reported by the native side.
  ///
  /// Returns `null` for unknown values, for instance when a newer ML Kit
  /// version reports a symbology this plugin does not model yet.
  static BarcodeFormat? fromValue(int? value) {
    if (value == null) {
      return null;
    }
    for (final format in BarcodeFormat.values) {
      if (format.value == value) {
        return format;
      }
    }
    return null;
  }
}

/// Kind of content encoded in a barcode, as classified by ML Kit.
///
/// The integer values are the ML Kit `Barcode.TYPE_*` constants.
enum BarcodeValueType {
  unknown(0),
  contactInfo(1),
  email(2),
  isbn(3),
  phone(4),
  product(5),
  sms(6),
  text(7),
  url(8),
  wifi(9),
  geo(10),
  calendarEvent(11),
  driverLicense(12);

  const BarcodeValueType(this.value);

  /// The ML Kit constant backing this value type.
  final int value;

  /// Resolves the value type reported by the native side, defaulting to
  /// [BarcodeValueType.unknown].
  static BarcodeValueType fromValue(int? value) {
    if (value == null) {
      return BarcodeValueType.unknown;
    }
    for (final type in BarcodeValueType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return BarcodeValueType.unknown;
  }
}
