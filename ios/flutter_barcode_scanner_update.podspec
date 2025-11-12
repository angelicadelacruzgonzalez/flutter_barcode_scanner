Pod::Spec.new do |s|
  s.name             = 'flutter_barcode_scanner_update'
  s.version          = '2.1.5'
  s.summary          = 'A new Flutter plugin supports barcode scanning on both Android and iOS.'
  s.description      = <<-DESC
A new Flutter plugin supports barcode scanning on both Android and iOS.
  DESC
  s.homepage         = 'https://github.com/angelicadelacruzgonzalez/flutter_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Angelica de la Cruz Gonzalez' => 'angelicadelacruzgonzalez@gmail.com' }
  s.source           = { :path => '.' }

  # Archivos fuente
  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.resources        = 'Assets/*.png'

  # Dependencias
  s.dependency       'Flutter'
  s.dependency       'GoogleMLKit/BarcodeScanning'

  # Configuración iOS
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'

  # 🔑 Evita problemas de linking al compilar Swift
  s.static_framework = true
end
