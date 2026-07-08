
## 2.1.9 - 2026-07-07

Migración a Kotlin integrado (built-in Kotlin) de Flutter, compatible con AGP 9+.

* Se elimina `apply plugin: "kotlin-android"` y se reemplaza `kotlinOptions` por `kotlin { compilerOptions { ... } }`.
* Se elimina `buildToolsVersion` obsoleto.
* Se actualiza `compileOptions` de Java 8 a Java 11.
* Se fija `compileSdk` en 36.
* `lintOptions` → `lint` (sintaxis moderna de AGP).
* Se elimina dependencia duplicada de `com.google.mlkit:barcode-scanning`.
## 2.1.8
- Update ndkVersion for 28.2.13676358

## 2.1.7
- Update of targetSdkVersion

## 2.1.6 
- Fixed first scan not detecting barcode
- Improved CameraX initialization timing
- Better stability on Android devices

## 2.1.5
* Novedades y mejoras

Se mejoró la gestión del flujo de escaneo para evitar errores cuando el usuario cancela el proceso.

Ahora, al cancelar manualmente el escaneo, el método scanBarcode() devuelve de forma controlada un valor '-1' o una cadena vacía (''), evitando la excepción PlatformException(CANCELLED, User cancelled scan, null, null).

Se añadieron validaciones adicionales y manejo seguro de errores para una mejor estabilidad.

Limpieza general del código y optimización menor en la comunicación con el canal nativo.
 Compatibilidad

Compatible con versiones anteriores.

No se requieren cambios en la implementación existente, aunque se recomienda actualizar para mejorar la estabilidad.
## 2.1.4
* SDK changes and updated features compatible with Flutter 3.35.5


## 2.1.3
* Change SDK version

## 2.1.2
*Added usage instructions.
<!--

-->
* 



## 2.1.1

* Android: version 
* iOS: Fixes #97
* PR: #184 and #182


## 1.0.1

* Merge PR #90
* iOS: Issue #82 fix 
* Android: Issue #62 fix

## 1.0.0

* Enhancement: Fixes mentioned issues #60, #59, #55, #53, #49, #43, #41, #37, #65, #63, #64, #71, #79.
* Android: New API migration.
* iOS: Now supports landscape mode in scanning.

## 0.1.7

* Enhancement: Issue #14, Added separate graphics overlay for Barcode and QR code.

## 0.1.6

* Android: Issue #31 fix (Out of memory crash).
* iOS: Issue #34 fix (Flash icon mismatch).

## 0.1.5+2

* iOS: No response on cancel button click (Fixes issue #33).

## 0.1.5+1

* Android: Potential issue fix Unhandled Exception: MissingPluginException.

## 0.1.5

* iOS: Camera permission issue fix (fixes issue #24).

## 0.1.4

* iOS: Added check for camera permission. Ask user to grant camera permission.

## 0.1.3

* Android: Continuous scan not working issue fix.

## 0.1.2+1

* iOS: Added support for ARGB color code which was not supported earlier.

## 0.1.2

* iOS: flash icon not visible for some devices issue fix.

## 0.1.1

* Removed unnecessary code.

## 0.1.0

* New feature (Issue #18): Now barcodes can be scanned continuously without closing camera.
* Upgraded workspace for Android and iOS

## 0.0.9

* Potential bug fix for issue #9 (Swift 3 inference for @Objc)

## 0.0.8

* Added one more parameter in `scanBarcode` which is `isShowFlashIcon`. 
Now you can pass bool value of your choice to show or hide the flash icon.
* Upgraded example code to Swift 5. Plugin is now Swift 5 compatible.

## 0.0.7

* Added one more parameter in `scanBarcode` which is `CANCEL_BUTTON_TEXT`. 
Now you can pass text of your choice and your language choice.

## 0.0.6

* Bug fixes and improvements

## 0.0.5

* Added support for Android X

## 0.0.4

* Bug fixes and improvements

## 0.0.3

* Added Android Support for 16 and above
* Minor changes and bug fixes

## 0.0.2

* Minor bug fixes and improvements

## 0.0.1

* Initial release.