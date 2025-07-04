#import "FlutterBarcodeScannerPlugin.h"
#import <flutter_barcode_scanner_update/flutter_barcode_scanner_update-Swift.h>

@implementation FlutterBarcodeScannerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterBarcodeScannerPlugin registerWithRegistrar:registrar];
}
@end
