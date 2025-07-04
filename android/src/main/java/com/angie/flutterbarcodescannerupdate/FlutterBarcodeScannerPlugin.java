package com.angie.flutterbarcodescannerupdate;

import android.app.Activity;
import android.app.Application;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.vision.barcode.Barcode;

import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;

/** FlutterBarcodeScannerPlugin */
public class FlutterBarcodeScannerPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
    private static final String CHANNEL = "flutter_barcode_scanner";
    private static final String EVENT_CHANNEL = "flutter_barcode_scanner_receiver";
    private static final String TAG = FlutterBarcodeScannerPlugin.class.getSimpleName();
    private static final int RC_BARCODE_CAPTURE = 9001;

    private static Activity activity;
    private static Result pendingResult;
    private Map<String, Object> arguments;
    private static EventChannel.EventSink barcodeStream;

    private MethodChannel channel;
    private EventChannel eventChannel;
    private Application applicationContext;
    private ActivityPluginBinding activityBinding;
    private FlutterPluginBinding pluginBinding;
    private Lifecycle lifecycle;
    private LifeCycleObserver observer;

    public static String lineColor = "";
    public static boolean isShowFlashIcon = false;
    public static boolean isContinuousScan = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        pluginBinding = binding;
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        channel.setMethodCallHandler(this);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            pendingResult = result;

            if (call.method.equals("scanBarcode")) {
                if (!(call.arguments instanceof Map)) {
                    throw new IllegalArgumentException("Expected a map as parameter");
                }

                arguments = (Map<String, Object>) call.arguments;
                lineColor = (String) arguments.get("lineColor");
                isShowFlashIcon = (boolean) arguments.get("isShowFlashIcon");
                isContinuousScan = (boolean) arguments.get("isContinuousScan");

                if (lineColor == null || lineColor.isEmpty()) {
                    lineColor = "#DC143C";
                }

                if (arguments.get("scanMode") != null) {
                    if ((int) arguments.get("scanMode") == BarcodeCaptureActivity.SCAN_MODE_ENUM.DEFAULT.ordinal()) {
                        BarcodeCaptureActivity.SCAN_MODE = BarcodeCaptureActivity.SCAN_MODE_ENUM.QR.ordinal();
                    } else {
                        BarcodeCaptureActivity.SCAN_MODE = (int) arguments.get("scanMode");
                    }
                } else {
                    BarcodeCaptureActivity.SCAN_MODE = BarcodeCaptureActivity.SCAN_MODE_ENUM.QR.ordinal();
                }

                startBarcodeScannerActivityView((String) arguments.get("cancelButtonText"), isContinuousScan);
            }
        } catch (Exception e) {
            Log.e(TAG, "onMethodCall: " + e.getLocalizedMessage());
        }
    }

    private void startBarcodeScannerActivityView(String buttonText, boolean isContinuousScan) {
        try {
            Intent intent = new Intent(activity, BarcodeCaptureActivity.class);
            intent.putExtra("cancelButtonText", buttonText);
            if (isContinuousScan) {
                activity.startActivity(intent);
            } else {
                activity.startActivityForResult(intent, RC_BARCODE_CAPTURE);
            }
        } catch (Exception e) {
            Log.e(TAG, "startView: " + e.getLocalizedMessage());
        }
    }


    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RC_BARCODE_CAPTURE && pendingResult != null) {
            if (resultCode == CommonStatusCodes.SUCCESS && data != null) {
                try {
                    Barcode barcode = data.getParcelableExtra(BarcodeCaptureActivity.BarcodeObject);
                    pendingResult.success(barcode.rawValue);
                } catch (Exception e) {
                    pendingResult.success("-1");
                }
            } else {
                pendingResult.success("-1");
            }
            pendingResult = null;
            arguments = null;
            return true;
        }
        return false;
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        barcodeStream = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        barcodeStream = null;
    }

    public static void onBarcodeScanReceiver(final Barcode barcode) {
        if (barcode != null && barcode.displayValue != null && !barcode.displayValue.isEmpty()) {
            activity.runOnUiThread(() -> {
                if (barcodeStream != null) {
                    barcodeStream.success(barcode.rawValue);
                }
            });
        }
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();
        activityBinding.addActivityResultListener(this::onActivityResult);

        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding);
        observer = new LifeCycleObserver(activity);
        lifecycle.addObserver(observer);
    }

    @Override
    public void onDetachedFromActivity() {
        clearPluginSetup();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        pluginBinding = null;
        if (channel != null) channel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
    }

    private void clearPluginSetup() {
        if (activityBinding != null) {
            activityBinding.removeActivityResultListener(this::onActivityResult);
        }
        if (lifecycle != null && observer != null) {
            lifecycle.removeObserver(observer);
        }
        activity = null;
        activityBinding = null;
        lifecycle = null;
        observer = null;
    }

    private static class LifeCycleObserver implements Application.ActivityLifecycleCallbacks, DefaultLifecycleObserver {
        private final Activity thisActivity;

        LifeCycleObserver(Activity activity) {
            this.thisActivity = activity;
        }

        @Override
        public void onStart(@NonNull LifecycleOwner owner) {}
        @Override
        public void onResume(@NonNull LifecycleOwner owner) {}
        @Override
        public void onPause(@NonNull LifecycleOwner owner) {}
        @Override
        public void onStop(@NonNull LifecycleOwner owner) {
            onActivityStopped(thisActivity);
        }
        @Override
        public void onDestroy(@NonNull LifecycleOwner owner) {
            onActivityDestroyed(thisActivity);
        }
        @Override
        public void onActivityCreated(Activity activity, Bundle savedInstanceState) {}
        @Override
        public void onActivityStarted(Activity activity) {}
        @Override
        public void onActivityResumed(Activity activity) {}
        @Override
        public void onActivityPaused(Activity activity) {}
        @Override
        public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}
        @Override
        public void onActivityDestroyed(Activity activity) {}
        @Override
        public void onActivityStopped(Activity activity) {}
    }
}
