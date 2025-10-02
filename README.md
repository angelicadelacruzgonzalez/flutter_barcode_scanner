# 📷 flutter_barcode_scanner_update

🎯 Versión personalizada y mejorada del plugin [`flutter_barcode_scanner`](https://github.com/AmolGangadhare/flutter_barcode_scanner) con soporte completo para escaneo de **códigos QR** y **códigos de barras** en **Android** e **iOS**.

[![pub version](https://img.shields.io/badge/pub-unpublished-inactive.svg)](https://pub.dev)
![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)

![Demo](https://github.com/AmolGangadhare/MyProfileRepo/blob/master/flutter_barcode_scanning_demo.gif "Demo")

---

## 🚀 Características

- Escaneo único (`scanBarcode`) o escaneo continuo (`getBarcodeStreamReceiver`)
- Personalización de color de línea y texto del botón cancelar
- Soporte para mostrar/ocultar ícono de flash
- Gráficos para QR y códigos de barras
- Compatible con Android e iOS

---

## 🛠️ Instalación

Agrega la dependencia en tu archivo `pubspec.yaml`:

```yaml
dependencies:
  flutter_barcode_scanner_update:
    git:
      url: https://github.com/angelicadelacruzgonzalez/flutter_barcode_scanner.git
```

---

## 📱 Configuración por plataforma

### ✅ Android

No requiere configuración adicional.

---

### 🍎 iOS (mínimo iOS 13)

#### 🔹 Si tu proyecto ya usa Swift:

1. Abre el proyecto iOS (`ios/Runner.xcworkspace`) en Xcode
2. En _Runner → Build Settings_:
   - Cambia `iOS Deployment Target` a **12.0**
   - Asegúrate de que `Swift Version` esté en **5.0**
3. Ejecuta `pod install` dentro del directorio `/ios`

#### 🔹 Si tu proyecto usa Objective-C:

1. Crea un nuevo proyecto Flutter con **soporte Swift**
2. Copia el directorio `/ios` desde el nuevo proyecto al tuyo
3. Sigue los pasos anteriores para configurar iOS 13 y Swift 5

#### 📷 Permiso de cámara

Agrega esta línea en `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para escanear códigos.</string>
```

---

## 🧪 Ejemplo de uso

### Escaneo único:

```dart
import 'package:flutter_barcode_scanner_update/flutter_barcode_scanner_update.dart';

String barcode = await FlutterBarcodeScannerUpdate.scanBarcode(
  "#ff6666",         // Color de la línea del escáner
  "Cancelar",        // Texto del botón cancelar
  true,              // Mostrar ícono de flash
  ScanMode.BARCODE   // Modo de escaneo: QR, BARCODE o DEFAULT
);
```

---

### Escaneo continuo:

```dart
FlutterBarcodeScannerUpdate.getBarcodeStreamReceiver(
  "#ff6666", "Cancelar", false, ScanMode.QR
).listen((barcode) {
  print('Código escaneado: $barcode');
});
```

---

## ℹ️ Notas

- `ScanMode.DEFAULT` mostrará la interfaz de escaneo tipo QR por defecto.
- Independientemente del `ScanMode`, el plugin detecta **tanto QR como códigos de barras**.
- Si el usuario cancela el escaneo, el resultado será `"-1"`.

---

## 🤝 Contribuciones

¿Te gustaría colaborar? ¡Tus contribuciones son bienvenidas! Abre un issue o PR para sugerencias, mejoras o correcciones.

---

## 📬 Contacto

Hecho con ❤️ por [Angélica de la Cruz González](https://github.com/angelicadelacruzgonzalez)  
Email: angelicadelacruzgonzalez@gmail.com

---
