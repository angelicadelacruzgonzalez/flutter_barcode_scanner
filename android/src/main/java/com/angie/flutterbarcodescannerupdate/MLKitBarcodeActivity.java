package com.angie.flutterbarcodescannerupdate;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ExperimentalGetImage;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;

import com.angie.flutterbarcodescannerupdate.constants.AppConstants;
import com.angie.flutterbarcodescannerupdate.utils.AppUtil;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;

import java.lang.ref.WeakReference;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Full screen scanner backed by CameraX and ML Kit.
 *
 * <p>All of the appearance options exposed by the Dart API are honoured here:
 * {@code lineColor} and {@code scanMode} drive {@link ScannerOverlayView},
 * {@code cancelButtonText} labels the dismiss button and {@code isShowFlashIcon}
 * shows or hides the torch toggle.
 *
 * <p>In single scan mode the result travels back through
 * {@code setResult}/{@code onActivityResult}. In continuous mode every new code
 * is pushed to the plugin's event channel and the screen stays open until Dart
 * calls {@code stopBarcodeStream} or the user dismisses it.
 */
public class MLKitBarcodeActivity extends AppCompatActivity {

    private static final String TAG = "MLKitBarcodeActivity";

    /**
     * Reference to the visible instance so {@code stopBarcodeStream} can close it.
     * Weak, so a leaked reference can never keep a destroyed activity alive.
     */
    @Nullable
    private static WeakReference<MLKitBarcodeActivity> activeInstance;

    private PreviewView previewView;
    private ScannerOverlayView overlayView;
    private ImageView flashButton;
    private Button cancelButton;

    @Nullable
    private ExecutorService analysisExecutor;
    @Nullable
    private BarcodeScanner barcodeScanner;
    @Nullable
    private ProcessCameraProvider cameraProvider;
    @Nullable
    private Camera camera;

    private boolean isContinuousScan;
    private boolean isShowFlashIcon;
    private boolean isTorchOn;
    private boolean hasDeliveredResult;
    private int scanMode = AppConstants.SCAN_MODE_QR;

    private final AtomicInteger frameCount = new AtomicInteger();
    @Nullable
    private String lastBarcode;
    private long lastBarcodeAtMillis;

    /** Closes the visible scanner, if any. Safe to call from any thread. */
    public static void closeActiveInstance() {
        final WeakReference<MLKitBarcodeActivity> reference = activeInstance;
        if (reference == null) {
            return;
        }
        final MLKitBarcodeActivity activity = reference.get();
        if (activity != null && !activity.isFinishing()) {
            activity.runOnUiThread(activity::finish);
        }
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.barcode_capture);

        activeInstance = new WeakReference<>(this);
        readArguments();
        bindViews();

        analysisExecutor = Executors.newSingleThreadExecutor();
        barcodeScanner = BarcodeScanning.getClient(buildScannerOptions());

        startCamera();
    }

    /**
     * Restricts detection to the symbologies requested from Dart. Narrowing the
     * set both speeds up detection and prevents reading an unrelated code that
     * happens to be in frame.
     */
    @NonNull
    private BarcodeScannerOptions buildScannerOptions() {
        final int bitmask = getIntent().getIntExtra(AppConstants.EXTRA_FORMATS, 0);
        final int[] formats = BarcodePayload.decodeFormats(bitmask);

        if (formats.length == 0) {
            return new BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                    .build();
        }

        final int[] remaining = new int[formats.length - 1];
        System.arraycopy(formats, 1, remaining, 0, remaining.length);
        return new BarcodeScannerOptions.Builder()
                .setBarcodeFormats(formats[0], remaining)
                .build();
    }

    private void readArguments() {
        final Intent intent = getIntent();
        isContinuousScan = intent.getBooleanExtra(AppConstants.EXTRA_IS_CONTINUOUS_SCAN, false);
        isShowFlashIcon = intent.getBooleanExtra(AppConstants.EXTRA_IS_SHOW_FLASH_ICON, true);
        scanMode = intent.getIntExtra(AppConstants.EXTRA_SCAN_MODE, AppConstants.SCAN_MODE_QR);
    }

    private void bindViews() {
        previewView = findViewById(R.id.previewView);
        overlayView = findViewById(R.id.scannerOverlay);
        flashButton = findViewById(R.id.flashButton);
        cancelButton = findViewById(R.id.cancelButton);

        final Intent intent = getIntent();
        overlayView.configure(scanMode, intent.getStringExtra(AppConstants.EXTRA_LINE_COLOR));

        final String cancelText = intent.getStringExtra(AppConstants.EXTRA_CANCEL_BUTTON_TEXT);
        if (cancelText != null && !cancelText.trim().isEmpty()) {
            cancelButton.setText(cancelText);
        }
        cancelButton.setOnClickListener(view -> cancelScan());

        flashButton.setVisibility(isShowFlashIcon ? android.view.View.VISIBLE : android.view.View.GONE);
        flashButton.setOnClickListener(view -> toggleTorch());
    }

    private void startCamera() {
        final ListenableFuture<ProcessCameraProvider> cameraProviderFuture =
                ProcessCameraProvider.getInstance(this);

        cameraProviderFuture.addListener(() -> {
            try {
                cameraProvider = cameraProviderFuture.get();
                bindUseCases(cameraProvider);
            } catch (Exception e) {
                Log.e(TAG, "Unable to obtain the camera provider", e);
                failWithCameraError();
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void bindUseCases(@NonNull ProcessCameraProvider provider) {
        final Preview preview = new Preview.Builder().build();

        final CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .build();

        final ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build();

        final ExecutorService executor = analysisExecutor;
        if (executor == null) {
            return;
        }
        imageAnalysis.setAnalyzer(executor, this::analyzeImage);

        provider.unbindAll();

        // Attach the surface only once the view is laid out, then bind after a
        // short delay. See AppConstants.PREVIEW_BIND_DELAY_MS.
        previewView.post(() -> {
            preview.setSurfaceProvider(previewView.getSurfaceProvider());
            previewView.postDelayed(() -> {
                if (isFinishing() || isDestroyed()) {
                    return;
                }
                try {
                    camera = provider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis);
                    applyTorchState();
                } catch (Exception e) {
                    Log.e(TAG, "Unable to bind the camera use cases", e);
                    failWithCameraError();
                }
            }, AppConstants.PREVIEW_BIND_DELAY_MS);
        });
    }

    @OptIn(markerClass = ExperimentalGetImage.class)
    private void analyzeImage(@NonNull ImageProxy imageProxy) {
        // Discard the warm-up frames so the first scan is not attempted on an
        // under-exposed or out-of-focus image.
        if (frameCount.incrementAndGet() <= AppConstants.WARM_UP_FRAMES) {
            imageProxy.close();
            return;
        }

        final android.media.Image image = imageProxy.getImage();
        final BarcodeScanner scanner = barcodeScanner;
        if (image == null || scanner == null || hasDeliveredResult) {
            imageProxy.close();
            return;
        }

        final InputImage inputImage =
                InputImage.fromMediaImage(image, imageProxy.getImageInfo().getRotationDegrees());

        scanner.process(inputImage)
                .addOnSuccessListener(this::handleBarcodes)
                .addOnFailureListener(e -> Log.w(TAG, "Barcode detection failed", e))
                .addOnCompleteListener(task -> imageProxy.close());
    }

    /** Runs on the main thread: ML Kit dispatches its listeners there by default. */
    private void handleBarcodes(@NonNull List<Barcode> barcodes) {
        if (barcodes.isEmpty() || hasDeliveredResult) {
            return;
        }

        BarcodePayload payload = null;
        for (Barcode barcode : barcodes) {
            payload = BarcodePayload.from(barcode);
            if (payload != null) {
                break;
            }
        }
        if (payload == null) {
            return;
        }

        if (isContinuousScan) {
            if (isDuplicate(payload.rawValue)) {
                return;
            }
            // The stream contract is a Stream<String>, so only the raw value is
            // pushed. Use scanBarcodeWithOptions when metadata is needed.
            FlutterBarcodeScannerPlugin.sendBarcodeToStream(payload.rawValue);
        } else {
            finishWithResult(payload);
        }
    }

    private boolean isDuplicate(@NonNull String value) {
        final long now = System.currentTimeMillis();
        final boolean duplicate = value.equals(lastBarcode)
                && (now - lastBarcodeAtMillis) < AppConstants.DUPLICATE_SCAN_WINDOW_MS;
        if (!duplicate) {
            lastBarcode = value;
            lastBarcodeAtMillis = now;
        }
        return duplicate;
    }

    private void finishWithResult(@NonNull BarcodePayload payload) {
        if (hasDeliveredResult) {
            return;
        }
        hasDeliveredResult = true;

        final Intent data = new Intent();
        payload.writeTo(data);
        setResult(RESULT_OK, data);
        finish();
    }

    private void cancelScan() {
        setResult(RESULT_CANCELED);
        finish();
    }

    private void failWithCameraError() {
        Toast.makeText(this, R.string.barcode_scanner_camera_error, Toast.LENGTH_LONG).show();
        cancelScan();
    }

    private void toggleTorch() {
        if (camera == null || !camera.getCameraInfo().hasFlashUnit()) {
            return;
        }
        isTorchOn = !isTorchOn;
        applyTorchState();
    }

    private void applyTorchState() {
        if (camera == null) {
            return;
        }
        if (camera.getCameraInfo().hasFlashUnit()) {
            camera.getCameraControl().enableTorch(isTorchOn);
        } else {
            isTorchOn = false;
            flashButton.setEnabled(false);
            flashButton.setAlpha(0.4f);
        }
        flashButton.setImageResource(isTorchOn
                ? R.drawable.ic_barcode_flash_on
                : R.drawable.ic_barcode_flash_off);
        flashButton.setColorFilter(AppUtil.parseColor(
                getIntent().getStringExtra(AppConstants.EXTRA_LINE_COLOR),
                AppConstants.DEFAULT_LINE_COLOR));
    }

    @Override
    protected void onDestroy() {
        final WeakReference<MLKitBarcodeActivity> reference = activeInstance;
        if (reference != null && reference.get() == this) {
            activeInstance = null;
        }

        if (cameraProvider != null) {
            cameraProvider.unbindAll();
            cameraProvider = null;
        }
        camera = null;

        if (barcodeScanner != null) {
            barcodeScanner.close();
            barcodeScanner = null;
        }
        if (analysisExecutor != null) {
            analysisExecutor.shutdown();
            analysisExecutor = null;
        }

        // Let Dart know the continuous stream is over, otherwise the returned
        // Stream would stay open after the user dismissed the scanner.
        if (isContinuousScan) {
            FlutterBarcodeScannerPlugin.onScannerClosed();
        }

        super.onDestroy();
    }
}
