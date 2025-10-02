/* package com.angie.flutterbarcodescannerupdate;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class FlutterBarcodeScannerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private MethodChannel channel;
    private EventChannel eventChannel;
    private Context context;
    private static EventChannel.EventSink eventSink;
    private Activity activity;

    private static final int CAMERA_REQUEST_CODE = 1001;
    private MethodCall pendingCall;
    private MethodChannel.Result pendingResult;
    private boolean isContinuous = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_barcode_scanner_update");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "flutter_barcode_scanner_update/stream");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink sink) {
                eventSink = sink;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "scanBarcode":
                isContinuous = false;
                checkPermissionAndStart(call, result);
                break;
            case "startBarcodeStream":
                isContinuous = true;
                checkPermissionAndStart(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void checkPermissionAndStart(MethodCall call, MethodChannel.Result result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) 
                == PackageManager.PERMISSION_GRANTED) {
            startActivity(call);
            result.success("");
        } else {
            // guardar la llamada pendiente
            pendingCall = call;
            pendingResult = result;
            ActivityCompat.requestPermissions(activity,
                    new String[]{Manifest.permission.CAMERA},
                    CAMERA_REQUEST_CODE);
        }
    }

    private void startActivity(MethodCall call) {
        Integer scanModeIndex = call.argument("scanMode");
        Intent intent = new Intent(context, MLKitBarcodeActivity.class);
        intent.putExtra("scanMode", scanModeIndex);
        intent.putExtra("isContinuousScan", isContinuous);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    public static void sendScanResultToFlutter(String barcode) {
        if (eventSink != null) {
            eventSink.success(barcode);
        }
    }

    // ActivityAware callbacks
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();

        binding.addRequestPermissionsResultListener((requestCode, permissions, grantResults) -> {
            if (requestCode == CAMERA_REQUEST_CODE) {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    if (pendingCall != null && pendingResult != null) {
                        startActivity(pendingCall);
                        pendingResult.success("");
                    }
                } else {
                    if (pendingResult != null) {
                        pendingResult.error("PERMISSION_DENIED", "Camera permission denied", null);
                    }
                }
                pendingCall = null;
                pendingResult = null;
                return true;
            }
            return false;
        });
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }
}
 */

 package com.angie.flutterbarcodescannerupdate;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class FlutterBarcodeScannerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private MethodChannel channel;
    private EventChannel eventChannel;
    private Context context;
    private static EventChannel.EventSink eventSink;
    private Activity activity;

    private static final int CAMERA_REQUEST_CODE = 1001;
    private static final int BARCODE_REQUEST_CODE = 2001;

    private MethodCall pendingCall;
    private MethodChannel.Result pendingResult;
    private boolean isContinuous = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_barcode_scanner_update");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "flutter_barcode_scanner_update/stream");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink sink) {
                eventSink = sink;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "scanBarcode":
                isContinuous = false;
                checkPermissionAndStart(call, result);
                break;
            case "startBarcodeStream":
                isContinuous = true;
                checkPermissionAndStart(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void checkPermissionAndStart(MethodCall call, MethodChannel.Result result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED) {
            startActivity(call, result);
        } else {
            pendingCall = call;
            pendingResult = result;
            ActivityCompat.requestPermissions(activity,
                    new String[]{Manifest.permission.CAMERA},
                    CAMERA_REQUEST_CODE);
        }
    }

    private void startActivity(MethodCall call, MethodChannel.Result result) {
        Integer scanModeIndex = call.argument("scanMode");
        Intent intent = new Intent(context, MLKitBarcodeActivity.class);
        intent.putExtra("scanMode", scanModeIndex);
        intent.putExtra("isContinuousScan", isContinuous);

        if (isContinuous) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            result.success(""); // Stream lo maneja
        } else {
            pendingResult = result;
            activity.startActivityForResult(intent, BARCODE_REQUEST_CODE);
        }
    }

    public static void sendScanResultToFlutter(String barcode) {
        if (eventSink != null) {
            eventSink.success(barcode);
        }
    }

    // ActivityAware
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();

        binding.addRequestPermissionsResultListener((requestCode, permissions, grantResults) -> {
            if (requestCode == CAMERA_REQUEST_CODE) {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    if (pendingCall != null && pendingResult != null) {
                        startActivity(pendingCall, pendingResult);
                    }
                } else {
                    if (pendingResult != null) {
                        pendingResult.error("PERMISSION_DENIED", "Camera permission denied", null);
                    }
                }
                pendingCall = null;
                pendingResult = null;
                return true;
            }
            return false;
        });

        binding.addActivityResultListener((requestCode, resultCode, data) -> {
            if (requestCode == BARCODE_REQUEST_CODE) {
                if (pendingResult != null) {
                    if (resultCode == Activity.RESULT_OK && data != null) {
                        String barcode = data.getStringExtra("SCAN_RESULT");
                        pendingResult.success(barcode);
                    } else {
                        pendingResult.error("CANCELLED", "User cancelled scan", null);
                    }
                    pendingResult = null;
                }
                return true;
            }
            return false;
        });
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() { activity = null; }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() { activity = null; }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }
}
