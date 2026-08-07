package com.angie.flutterbarcodescannerupdate;

import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.angie.flutterbarcodescannerupdate.constants.AppConstants;
import com.google.mlkit.vision.barcode.common.Barcode;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The data reported for a detected code: raw value plus the metadata ML Kit
 * already computed. Travels from {@link MLKitBarcodeActivity} to
 * {@link FlutterBarcodeScannerPlugin} as intent extras and reaches Dart as the
 * map consumed by {@code BarcodeResult.fromMap}.
 */
final class BarcodePayload {

    /**
     * Every symbology this plugin can request, in the order used to decompose the
     * bitmask sent from Dart. Must stay in sync with the Dart {@code BarcodeFormat}
     * enum.
     */
    private static final int[] SUPPORTED_FORMATS = {
            Barcode.FORMAT_CODE_128,
            Barcode.FORMAT_CODE_39,
            Barcode.FORMAT_CODE_93,
            Barcode.FORMAT_CODABAR,
            Barcode.FORMAT_DATA_MATRIX,
            Barcode.FORMAT_EAN_13,
            Barcode.FORMAT_EAN_8,
            Barcode.FORMAT_ITF,
            Barcode.FORMAT_QR_CODE,
            Barcode.FORMAT_UPC_A,
            Barcode.FORMAT_UPC_E,
            Barcode.FORMAT_PDF417,
            Barcode.FORMAT_AZTEC
    };

    @NonNull
    final String rawValue;
    @Nullable
    final String displayValue;
    final int format;
    final int valueType;

    private BarcodePayload(@NonNull String rawValue, @Nullable String displayValue,
                           int format, int valueType) {
        this.rawValue = rawValue;
        this.displayValue = displayValue;
        this.format = format;
        this.valueType = valueType;
    }

    /** Returns {@code null} when the code carries no usable raw value. */
    @Nullable
    static BarcodePayload from(@NonNull Barcode barcode) {
        final String rawValue = barcode.getRawValue();
        if (rawValue == null || rawValue.isEmpty()) {
            return null;
        }
        return new BarcodePayload(
                rawValue,
                barcode.getDisplayValue(),
                barcode.getFormat(),
                barcode.getValueType());
    }

    /** Reads a payload back from the activity result intent. */
    @Nullable
    static BarcodePayload from(@Nullable Intent intent) {
        if (intent == null) {
            return null;
        }
        final String rawValue = intent.getStringExtra(AppConstants.EXTRA_SCAN_RESULT);
        if (rawValue == null || rawValue.isEmpty()) {
            return null;
        }
        return new BarcodePayload(
                rawValue,
                intent.getStringExtra(AppConstants.EXTRA_SCAN_DISPLAY_VALUE),
                intent.getIntExtra(AppConstants.EXTRA_SCAN_FORMAT, Barcode.FORMAT_UNKNOWN),
                intent.getIntExtra(AppConstants.EXTRA_SCAN_VALUE_TYPE, Barcode.TYPE_UNKNOWN));
    }

    void writeTo(@NonNull Intent intent) {
        intent.putExtra(AppConstants.EXTRA_SCAN_RESULT, rawValue);
        intent.putExtra(AppConstants.EXTRA_SCAN_DISPLAY_VALUE, displayValue);
        intent.putExtra(AppConstants.EXTRA_SCAN_FORMAT, format);
        intent.putExtra(AppConstants.EXTRA_SCAN_VALUE_TYPE, valueType);
    }

    /** Serialises the payload for the method channel. */
    @NonNull
    Map<String, Object> toMap() {
        final Map<String, Object> map = new HashMap<>();
        map.put("rawValue", rawValue);
        map.put("displayValue", displayValue);
        map.put("format", format);
        map.put("valueType", valueType);
        return map;
    }

    /**
     * Splits the bitmask sent from Dart into the individual ML Kit constants
     * expected by {@code BarcodeScannerOptions.Builder#setBarcodeFormats}.
     *
     * <p>Returns an empty array when no format is requested, meaning the caller
     * should accept every supported symbology.
     */
    @NonNull
    static int[] decodeFormats(int bitmask) {
        if (bitmask == 0) {
            return new int[0];
        }

        final List<Integer> formats = new ArrayList<>();
        for (int format : SUPPORTED_FORMATS) {
            if ((bitmask & format) == format) {
                formats.add(format);
            }
        }

        final int[] result = new int[formats.size()];
        for (int i = 0; i < formats.size(); i++) {
            result[i] = formats.get(i);
        }
        return result;
    }
}
