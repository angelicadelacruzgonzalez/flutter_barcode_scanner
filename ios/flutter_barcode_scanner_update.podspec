#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_barcode_scanner_update'
  s.version          = '2.1.1'
  s.summary          = 'A new Flutter plugin supports barcode scanning on both Android and iOS.'
  s.description      = <<-DESC
A new Flutter plugin supports barcode scanning on both Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/angelicadelacruzgonzalez/flutter_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Angelica de la Cruz Gonzalez' => 'angelicadelacruzgonzalez@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{swift,h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.resources = 'Assets/*.png'
  s.dependency 'Flutter'

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
end
