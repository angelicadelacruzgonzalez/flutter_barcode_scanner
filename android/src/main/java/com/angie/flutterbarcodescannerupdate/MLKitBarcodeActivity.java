
package com.angie.flutterbarcodescannerupdate;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.Preview;
import androidx.camera.core.ImageProxy;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;
import java.util.List;
import java.util.concurrent.ExecutionException;

import android.app.Activity;
import android.content.Intent;


public class MLKitBarcodeActivity extends AppCompatActivity {

    private PreviewView previewView;
    private boolean isContinuousScan = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        previewView = new PreviewView(this);
        setContentView(previewView);

        isContinuousScan = getIntent().getBooleanExtra("isContinuousScan", false);
        startCamera();
    }

/* private void startCamera() { 
    ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(this); cameraProviderFuture.addListener(() -> { try { ProcessCameraProvider cameraProvider = cameraProviderFuture.get(); Preview preview = new Preview.Builder().build(); preview.setSurfaceProvider(previewView.getSurfaceProvider()); CameraSelector cameraSelector = new CameraSelector.Builder() .requireLensFacing(CameraSelector.LENS_FACING_BACK) .build(); ImageAnalysis imageAnalysis = new ImageAnalysis.Builder() .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST) .build(); BarcodeScanner scanner = BarcodeScanning.getClient(); imageAnalysis.setAnalyzer(ContextCompat.getMainExecutor(this), image -> { if (image.getImage() != null) { InputImage inputImage = InputImage.fromMediaImage(image.getImage(), image.getImageInfo().getRotationDegrees()); scanner.process(inputImage) .addOnSuccessListener(barcodes -> handleBarcodes(barcodes)) .addOnCompleteListener(task -> image.close()); } else { image.close(); } }); cameraProvider.unbindAll(); cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis);
 } catch (ExecutionException | InterruptedException e) { e.printStackTrace(); } }, ContextCompat.getMainExecutor(this)); }
 */
private void startCamera() {
    ListenableFuture<ProcessCameraProvider> cameraProviderFuture =
            ProcessCameraProvider.getInstance(this);

    cameraProviderFuture.addListener(() -> {
        try {
            ProcessCameraProvider cameraProvider = cameraProviderFuture.get();

            Preview preview = new Preview.Builder().build();

            CameraSelector cameraSelector = new CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                    .build();

            ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build();

            BarcodeScanner scanner = BarcodeScanning.getClient();

            // 🔥 Ignorar primeros frames (SIN dependencias nuevas)
            final int[] frameCount = {0};

            imageAnalysis.setAnalyzer(ContextCompat.getMainExecutor(this), image -> {

                frameCount[0]++;

                if (frameCount[0] < 5) {
                    image.close();
                    return;
                }

                if (image.getImage() != null) {
                    InputImage inputImage = InputImage.fromMediaImage(
                            image.getImage(),
                            image.getImageInfo().getRotationDegrees()
                    );

                    scanner.process(inputImage)
                            .addOnSuccessListener(barcodes -> handleBarcodes(barcodes))
                            .addOnCompleteListener(task -> image.close());
                } else {
                    image.close();
                }
            });

            cameraProvider.unbindAll();

            // 🔥 FIX CLAVE: esperar a que el preview esté listo
            previewView.post(() -> {

                preview.setSurfaceProvider(previewView.getSurfaceProvider());

                // 🔥 pequeño delay (SIN Handler extra)
                previewView.postDelayed(() -> {
                    cameraProvider.bindToLifecycle(
                            this,
                            cameraSelector,
                            preview,
                            imageAnalysis
                    );
                }, 250); // 👈 200–300 ideal

            });

        } catch (ExecutionException | InterruptedException e) {
            e.printStackTrace();
        }
    }, ContextCompat.getMainExecutor(this));
}
    private void handleBarcodes(List<Barcode> barcodes) {
    for (Barcode barcode : barcodes) {
        String value = barcode.getRawValue();

        if (isContinuousScan) {
            // 🔄 Stream continuo
            FlutterBarcodeScannerPlugin.sendScanResultToFlutter(value);
        } else {
            // ✅ Escaneo único → devolvemos el resultado al plugin
            Intent resultIntent = new Intent();
            resultIntent.putExtra("SCAN_RESULT", value);
            setResult(Activity.RESULT_OK, resultIntent);
            finish();
            break;
        }
    }
}

}
