package com.angie.flutterbarcodescannerupdate.utils;

import android.content.Context;
import android.graphics.Color;
import android.util.DisplayMetrics;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/** Small helpers shared by the scanner UI. */
public final class AppUtil {

    private AppUtil() {
    }

    /**
     * Converts density independent pixels to pixels.
     *
     * <p>Uses {@link DisplayMetrics#density}. A previous revision divided
     * {@code xdpi} by {@link DisplayMetrics#DENSITY_DEFAULT}, which returns the
     * physical pixel density and produced oversized dimensions on most devices.
     */
    public static int dpToPx(@NonNull Context context, int dp) {
        final DisplayMetrics metrics = context.getResources().getDisplayMetrics();
        return Math.round(dp * metrics.density);
    }

    /**
     * Parses a hex color coming from Dart.
     *
     * <p>Accepts {@code #RGB}, {@code #RRGGBB} and {@code #AARRGGBB}, with or
     * without the leading {@code #}. Returns the parsed {@code fallback} when the
     * value is missing or malformed, so a bad color never crashes the scanner.
     */
    public static int parseColor(@Nullable String color, @NonNull String fallback) {
        final Integer parsed = tryParseColor(color);
        if (parsed != null) {
            return parsed;
        }
        final Integer parsedFallback = tryParseColor(fallback);
        return parsedFallback != null ? parsedFallback : Color.WHITE;
    }

    @Nullable
    private static Integer tryParseColor(@Nullable String color) {
        if (color == null) {
            return null;
        }
        final String trimmed = color.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        final String normalized = trimmed.startsWith("#") ? trimmed : "#" + trimmed;
        try {
            return Color.parseColor(normalized);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
