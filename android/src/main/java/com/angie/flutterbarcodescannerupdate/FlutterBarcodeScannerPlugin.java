package com.angie.flutterbarcodescannerupdate;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.angie.flutterbarcodescannerupdate.constants.AppConstants;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Entry point of the barcode scanner plugin.
 *
 * <p>Exposes three methods to Dart:
 * <ul>
 *   <li>{@code scanBarcode} opens the scanner and returns the first code found.</li>
 *   <li>{@code startBarcodeStream} opens the scanner and pushes every code to the
 *       event channel {@code flutter_barcode_scanner_update/stream}.</li>
 *   <li>{@code stopBarcodeStream} closes a scanner opened in streaming mode.</li>
 * </ul>
 */
public class FlutterBarcodeScannerPlugin
        implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
        EventChannel.StreamHandler {

    private static final int CAMERA_REQUEST_CODE = 1001;
    private static final int BARCODE_REQUEST_CODE = 2001;

    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());

    /**
     * The sink is static because {@link MLKitBarcodeActivity} runs in its own
     * activity and has no reference to the plugin instance.
     */
    @Nullable
    private static volatile EventChannel.EventSink eventSink;

    @Nullable
    private MethodChannel methodChannel;
    @Nullable
    private EventChannel eventChannel;
    @Nullable
    private Context applicationContext;
    @Nullable
    private Activity activity;
    @Nullable
    private ActivityPluginBinding activityBinding;

    /** Pending result for a single scan awaiting {@code onActivityResult}. */
    @Nullable
    private MethodChannel.Result scanResult;
    /** Pending call and result awaiting the camera permission decision. */
    @Nullable
    private MethodCall permissionCall;
    @Nullable
    private MethodChannel.Result permissionResult;

    // Held as fields because a method reference creates a new instance on every
    // evaluation, which would make the remove* calls no-ops.
    private final PluginRegistry.RequestPermissionsResultListener permissionsListener =
            this::onRequestPermissionsResult;
    private final PluginRegistry.ActivityResultListener activityResultListener =
            this::onActivityResult;

    // MARK: - Static bridge used by MLKitBarcodeActivity

    /** Pushes a code to the Dart stream. Safe to call from any thread. */
    static void sendBarcodeToStream(@NonNull String barcode) {
        MAIN_HANDLER.post(() -> {
            final EventChannel.EventSink sink = eventSink;
            if (sink != null) {
                sink.success(barcode);
            }
        });
    }

    /** Signals that the streaming scanner was closed. Safe to call from any thread. */
    static void onScannerClosed() {
        MAIN_HANDLER.post(() -> {
            final EventChannel.EventSink sink = eventSink;
            if (sink != null) {
                sink.endOfStream();
            }
        });
    }

    // MARK: - FlutterPlugin

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();

        methodChannel = new MethodChannel(binding.getBinaryMessenger(), AppConstants.METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), AppConstants.EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }
        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }
        applicationContext = null;
        eventSink = null;
    }

    // MARK: - MethodCallHandler

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case AppConstants.METHOD_SCAN_BARCODE:
                startScan(call, result, false);
                break;
            case AppConstants.METHOD_START_STREAM:
                startScan(call, result, true);
                break;
            case AppConstants.METHOD_STOP_STREAM:
                MLKitBarcodeActivity.closeActiveInstance();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private void startScan(@NonNull MethodCall call, @NonNull MethodChannel.Result result,
                           boolean isContinuous) {
        if (activity == null || applicationContext == null) {
            result.error(AppConstants.ERROR_NO_ACTIVITY,
                    "The scanner cannot be opened while the plugin is detached from an Activity",
                    null);
            return;
        }

        if (!isContinuous && scanResult != null) {
            result.error(AppConstants.ERROR_ALREADY_RUNNING,
                    "A scan is already in progress", null);
            return;
        }

        if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED) {
            launchScanner(call, result, isContinuous);
            return;
        }

        permissionCall = call;
        permissionResult = result;
        ActivityCompat.requestPermissions(activity,
                new String[]{Manifest.permission.CAMERA},
                CAMERA_REQUEST_CODE);
    }

    private void launchScanner(@NonNull MethodCall call, @NonNull MethodChannel.Result result,
                               boolean isContinuous) {
        final Activity currentActivity = activity;
        if (currentActivity == null) {
            result.error(AppConstants.ERROR_NO_ACTIVITY, "No Activity available", null);
            return;
        }

        final Intent intent = new Intent(currentActivity, MLKitBarcodeActivity.class);
        intent.putExtra(AppConstants.EXTRA_LINE_COLOR,
                stringArgument(call, AppConstants.EXTRA_LINE_COLOR));
        intent.putExtra(AppConstants.EXTRA_CANCEL_BUTTON_TEXT,
                stringArgument(call, AppConstants.EXTRA_CANCEL_BUTTON_TEXT));
        intent.putExtra(AppConstants.EXTRA_IS_SHOW_FLASH_ICON,
                booleanArgument(call, AppConstants.EXTRA_IS_SHOW_FLASH_ICON, true));
        intent.putExtra(AppConstants.EXTRA_SCAN_MODE,
                intArgument(call, AppConstants.EXTRA_SCAN_MODE, AppConstants.SCAN_MODE_QR));
        intent.putExtra(AppConstants.EXTRA_FORMATS,
                intArgument(call, AppConstants.EXTRA_FORMATS, 0));
        intent.putExtra(AppConstants.EXTRA_IS_CONTINUOUS_SCAN, isContinuous);

        if (isContinuous) {
            // Results arrive through the event channel, so acknowledge immediately.
            currentActivity.startActivity(intent);
            result.success(null);
        } else {
            scanResult = result;
            currentActivity.startActivityForResult(intent, BARCODE_REQUEST_CODE);
        }
    }

    @Nullable
    private String stringArgument(@NonNull MethodCall call, @NonNull String key) {
        final Object value = call.argument(key);
        return value instanceof String ? (String) value : null;
    }

    private boolean booleanArgument(@NonNull MethodCall call, @NonNull String key,
                                    boolean fallback) {
        final Object value = call.argument(key);
        return value instanceof Boolean ? (Boolean) value : fallback;
    }

    private int intArgument(@NonNull MethodCall call, @NonNull String key, int fallback) {
        final Object value = call.argument(key);
        return value instanceof Number ? ((Number) value).intValue() : fallback;
    }

    // MARK: - EventChannel.StreamHandler

    @Override
    public void onListen(@Nullable Object arguments, @NonNull EventChannel.EventSink sink) {
        eventSink = sink;
    }

    @Override
    public void onCancel(@Nullable Object arguments) {
        eventSink = null;
    }

    // MARK: - ActivityAware

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        attachToActivity(binding);
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        attachToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachFromActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        detachFromActivity();
    }

    private void attachToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();

        binding.addRequestPermissionsResultListener(permissionsListener);
        binding.addActivityResultListener(activityResultListener);
    }

    private void detachFromActivity() {
        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(permissionsListener);
            activityBinding.removeActivityResultListener(activityResultListener);
            activityBinding = null;
        }
        activity = null;
    }

    private boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                               @NonNull int[] grantResults) {
        if (requestCode != CAMERA_REQUEST_CODE) {
            return false;
        }

        final MethodCall call = permissionCall;
        final MethodChannel.Result result = permissionResult;
        permissionCall = null;
        permissionResult = null;

        if (call == null || result == null) {
            return true;
        }

        final boolean granted = grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED;

        if (granted) {
            final boolean isContinuous =
                    booleanArgument(call, AppConstants.EXTRA_IS_CONTINUOUS_SCAN, false);
            launchScanner(call, result, isContinuous);
        } else {
            result.error(AppConstants.ERROR_PERMISSION_DENIED,
                    "Camera permission was denied", null);
        }
        return true;
    }

    private boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode != BARCODE_REQUEST_CODE) {
            return false;
        }

        final MethodChannel.Result result = scanResult;
        scanResult = null;

        if (result == null) {
            return true;
        }

        final BarcodePayload payload = resultCode == Activity.RESULT_OK
                ? BarcodePayload.from(data)
                : null;

        if (payload != null) {
            // Dart maps this to a BarcodeResult; the legacy scanBarcode wrapper
            // reads only the rawValue entry.
            result.success(payload.toMap());
        } else {
            result.error(AppConstants.ERROR_CANCELLED, "User cancelled the scan", null);
        }
        return true;
    }
}
