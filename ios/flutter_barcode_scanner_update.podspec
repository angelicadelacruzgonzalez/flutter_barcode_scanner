Pod::Spec.new do |s|
  s.name             = 'flutter_barcode_scanner_update'
  s.version          = '2.3.1'
  s.summary          = 'A Flutter plugin for barcode scanning on Android and iOS.'
  s.description      = <<-DESC
A Flutter plugin for barcode scanning on Android and iOS.
  DESC

  s.homepage         = 'https://github.com/angelicadelacruzgonzalez/flutter_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = {
    'Angelica de la Cruz Gonzalez' => 'angelicadelacruzgonzalez@gmail.com'
  }

  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.frameworks = 'UIKit', 'AVFoundation', 'Vision'

  s.static_framework = true
end

 