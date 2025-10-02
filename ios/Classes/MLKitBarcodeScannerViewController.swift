import UIKit
import Flutter
import MLKitVision
import MLKitBarcodeScanning


public class MLKitBarcodeScannerViewController: UIViewController {
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        startBarcodeScanning()
    }

    func startBarcodeScanning() {
        let format = BarcodeFormat.all
        let options = BarcodeScannerOptions(formats: format)
        let scanner = BarcodeScanner.barcodeScanner(options: options)

        guard let image = UIImage(named: "Assets/example.png") else { return }
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        scanner.process(visionImage) { barcodes, error in
            guard error == nil, let barcodes = barcodes else { return }
            for barcode in barcodes {
                print("Barcode detected: \(barcode.displayValue ?? "")")
            }
        }
    }
}
