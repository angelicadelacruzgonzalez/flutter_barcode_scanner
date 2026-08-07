# 📷 flutter_barcode_scanner_update

🎯 Versión personalizada y mantenida del plugin [`flutter_barcode_scanner`](https://github.com/AmolGangadhare/flutter_barcode_scanner), con escaneo de **códigos QR** y **códigos de barras** en **Android** e **iOS** sobre ML Kit (CameraX en Android, AVFoundation en iOS).

[![pub version](https://img.shields.io/badge/pub-unpublished-inactive.svg)](https://pub.dev)
![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)

---

## 🚀 Características

- Escaneo único (`scanBarcode`, `scanBarcodeWithOptions`) y continuo (`getBarcodeStreamReceiver`, `getBarcodeStreamWithOptions`)
- **Filtro de simbologías**: acepta solo los formatos que te interesan
- **Resultado enriquecido**: valor, valor visible, formato detectado y tipo de contenido
- Color de línea, texto del botón cancelar y visibilidad del flash configurables
- Overlay con ventana adaptada al modo (QR o código de barras)
- Linterna, escaneo en horizontal y cierre controlado del escaneo continuo

---

## 🛠️ Instalación

```yaml
dependencies:
  flutter_barcode_scanner_update:
    git:
      url: https://github.com/angelicadelacruzgonzalez/flutter_barcode_scanner.git
```

---

## 📱 Configuración por plataforma

### ✅ Android

No requiere configuración adicional. Requiere `minSdk 21` o superior.

### 🍎 iOS (mínimo iOS 13)

1. Abre `ios/Runner.xcworkspace` en Xcode
2. En _Runner → Build Settings_, deja `iOS Deployment Target` en **13.0** y `Swift Version` en **5.0**
3. Ejecuta `pod install` dentro de `/ios`

Agrega el permiso de cámara en `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para escanear códigos.</string>
```

---

## 🧪 Uso

### Escaneo único (API clásica)

```dart
import 'package:flutter_barcode_scanner_update/flutter_barcode_scanner_update.dart';

final String barcode = await FlutterBarcodeScanner.scanBarcode(
  '#3D8BEF',        // Color de la línea del escáner
  'Cancelar',       // Texto del botón cancelar
  false,            // Mostrar ícono de flash
  ScanMode.QR,      // QR, BARCODE o DEFAULT
);
```

Devuelve `'-1'` si el usuario cancela.

### Escaneo único con opciones y resultado enriquecido

```dart
final BarcodeResult? result = await FlutterBarcodeScanner.scanBarcodeWithOptions(
  const ScannerOptions(
    lineColor: '#3D8BEF',
    cancelButtonText: 'Cancelar',
    isShowFlashIcon: true,
    scanMode: ScanMode.BARCODE,
    // Solo simbologías de retail: un QR de marketing en cuadro se ignora
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.upcA,
    ],
  ),
);

if (result == null) {
  // El usuario canceló
} else {
  print(result.rawValue);       // Contenido crudo
  print(result.displayValue);   // Contenido legible, si ML Kit lo produce
  print(result.format?.name);   // ean13, qrCode, ...
  print(result.valueType.name); // product, url, wifi, text, ...
}
```

### Escaneo continuo

```dart
final subscription = FlutterBarcodeScanner.getBarcodeStreamWithOptions(
  const ScannerOptions(
    lineColor: '#3D8BEF',
    cancelButtonText: 'Cancelar',
    scanMode: ScanMode.QR,
    formats: [BarcodeFormat.qrCode],
  ),
).listen((barcode) {
  print('Código escaneado: $barcode');
});

// La cámara se cierra al cancelar la suscripción
await subscription.cancel();
// O explícitamente:
await FlutterBarcodeScanner.stopBarcodeStream();
```

---

## 📋 Formatos disponibles

`BarcodeFormat.code128`, `code39`, `code93`, `codabar`, `dataMatrix`, `ean13`, `ean8`, `itf`, `qrCode`, `upcA`, `upcE`, `pdf417`, `aztec`.

Una lista vacía en `ScannerOptions.formats` acepta todos los formatos.

---

## ℹ️ Notas

- `scanMode` solo controla la **forma de la ventana** del overlay. Para restringir qué se detecta usa `formats`.
- `ScanMode.DEFAULT` muestra la ventana cuadrada, igual que `ScanMode.QR`.
- Si el usuario cancela: `scanBarcode` devuelve `'-1'` y `scanBarcodeWithOptions` devuelve `null`.
- Los fallos reales (permiso de cámara denegado, error nativo) lanzan `PlatformException`, para poder distinguirlos de una cancelación:

```dart
try {
  final result = await FlutterBarcodeScanner.scanBarcodeWithOptions(options);
} on PlatformException catch (e) {
  // e.code: PERMISSION_DENIED | NO_ACTIVITY | ALREADY_RUNNING | NO_ROOT
}
```

- En escaneo continuo, un mismo código no se reemite durante ~1,5 s para evitar duplicados por frame.

---

## 🤝 Contribuciones

¿Te gustaría colaborar? Abre un issue o PR para sugerencias, mejoras o correcciones.

---

## 📬 Contacto

Hecho con ❤️ por [Angélica de la Cruz González](https://github.com/angelicadelacruzgonzalez)
Email: angelicadelacruzgonzalez@gmail.com
