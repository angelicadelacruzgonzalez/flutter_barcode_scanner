package com.angie.flutterbarcodescannerupdate.constants;

import android.graphics.Color;

/** Shared constants for the barcode scanner plugin. */
public final class AppConstants {

    private AppConstants() {
    }

    // Channel names. Must match the Dart side.
    public static final String METHOD_CHANNEL = "flutter_barcode_scanner_update";
    public static final String EVENT_CHANNEL = "flutter_barcode_scanner_update/stream";

    // Method names.
    public static final String METHOD_SCAN_BARCODE = "scanBarcode";
    public static final String METHOD_START_STREAM = "startBarcodeStream";
    public static final String METHOD_STOP_STREAM = "stopBarcodeStream";

    // Argument / intent extra keys. Must match the Dart side.
    public static final String EXTRA_LINE_COLOR = "lineColor";
    public static final String EXTRA_CANCEL_BUTTON_TEXT = "cancelButtonText";
    public static final String EXTRA_IS_SHOW_FLASH_ICON = "isShowFlashIcon";
    public static final String EXTRA_IS_CONTINUOUS_SCAN = "isContinuousScan";
    public static final String EXTRA_SCAN_MODE = "scanMode";
    /** Bitmask of the requested symbologies; 0 means every supported format. */
    public static final String EXTRA_FORMATS = "formats";

    // Intent extras carrying the detected code back to the plugin.
    public static final String EXTRA_SCAN_RESULT = "SCAN_RESULT";
    public static final String EXTRA_SCAN_DISPLAY_VALUE = "SCAN_DISPLAY_VALUE";
    public static final String EXTRA_SCAN_FORMAT = "SCAN_FORMAT";
    public static final String EXTRA_SCAN_VALUE_TYPE = "SCAN_VALUE_TYPE";

    // Error codes surfaced to Dart.
    public static final String ERROR_CANCELLED = "CANCELLED";
    public static final String ERROR_PERMISSION_DENIED = "PERMISSION_DENIED";
    public static final String ERROR_NO_ACTIVITY = "NO_ACTIVITY";
    public static final String ERROR_ALREADY_RUNNING = "ALREADY_RUNNING";

    // Scan modes. Must match the index order of the Dart ScanMode enum.
    public static final int SCAN_MODE_QR = 0;
    public static final int SCAN_MODE_BARCODE = 1;
    public static final int SCAN_MODE_DEFAULT = 2;

    // Overlay appearance.
    public static final String DEFAULT_LINE_COLOR = "#DC143C";
    public static final int SCRIM_COLOR = Color.argb(0x99, 0, 0, 0);
    public static final int LINE_WIDTH_DP = 2;
    public static final int LINE_INSET_DP = 8;
    public static final int CORNER_WIDTH_DP = 3;
    public static final float CORNER_LENGTH_RATIO = 0.12f;
    public static final long LINE_ANIMATION_DURATION_MS = 1800L;
    public static final float QR_WINDOW_SIDE_RATIO = 0.68f;
    public static final float BARCODE_WINDOW_WIDTH_RATIO = 0.85f;
    public static final float BARCODE_WINDOW_ASPECT_RATIO = 0.45f;

    /**
     * Number of frames discarded before running detection, giving the camera time
     * to settle exposure and focus. Without this the very first scan could return
     * a stale or unreadable frame on some devices.
     */
    public static final int WARM_UP_FRAMES = 5;

    /**
     * Delay applied before binding the CameraX use cases. Works around
     * intermittent preview rendering failures observed on some devices when
     * binding happens in the same frame the surface becomes available.
     */
    public static final long PREVIEW_BIND_DELAY_MS = 250L;

    /**
     * In continuous mode the same code is ignored while this window is open, so a
     * code held in front of the camera is not emitted on every frame.
     */
    public static final long DUPLICATE_SCAN_WINDOW_MS = 1500L;
}
