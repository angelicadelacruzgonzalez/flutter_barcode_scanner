package com.angie.flutterbarcodescannerupdate;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.LinearInterpolator;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.angie.flutterbarcodescannerupdate.constants.AppConstants;
import com.angie.flutterbarcodescannerupdate.utils.AppUtil;

/**
 * Draws the scanner guidance on top of the camera preview: a dimmed scrim with a
 * transparent scan window, corner brackets and an animated sweep line.
 *
 * <p>The window shape follows the {@code ScanMode} selected from Dart and the
 * sweep line uses the {@code lineColor} supplied by the caller. Detection itself
 * always runs on the full frame, so the window is purely visual guidance.
 */
public class ScannerOverlayView extends View {

    private final Paint scrimPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint cornerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF scanWindow = new RectF();

    private int scanMode = AppConstants.SCAN_MODE_QR;
    private float linePosition = 0f;
    @Nullable
    private ValueAnimator lineAnimator;

    public ScannerOverlayView(@NonNull Context context) {
        this(context, null);
    }

    public ScannerOverlayView(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        setLayerType(LAYER_TYPE_HARDWARE, null);

        scrimPaint.setColor(AppConstants.SCRIM_COLOR);
        scrimPaint.setStyle(Paint.Style.FILL);

        linePaint.setColor(Color.parseColor(AppConstants.DEFAULT_LINE_COLOR));
        linePaint.setStrokeWidth(AppUtil.dpToPx(getContext(), AppConstants.LINE_WIDTH_DP));
        linePaint.setStrokeCap(Paint.Cap.ROUND);

        cornerPaint.setColor(Color.WHITE);
        cornerPaint.setStyle(Paint.Style.STROKE);
        cornerPaint.setStrokeWidth(AppUtil.dpToPx(getContext(), AppConstants.CORNER_WIDTH_DP));
        cornerPaint.setStrokeCap(Paint.Cap.ROUND);
    }

    /**
     * Applies the caller supplied appearance.
     *
     * @param scanMode  one of the {@code AppConstants.SCAN_MODE_*} values.
     * @param lineColor hex color such as {@code #ff6666} or {@code #ccff6666};
     *                  falls back to the default when it cannot be parsed.
     */
    public void configure(int scanMode, @Nullable String lineColor) {
        this.scanMode = scanMode;
        linePaint.setColor(AppUtil.parseColor(lineColor, AppConstants.DEFAULT_LINE_COLOR));
        cornerPaint.setColor(linePaint.getColor());
        requestLayout();
        invalidate();
    }

    /** The guidance window, in view coordinates. */
    @NonNull
    public RectF getScanWindow() {
        return new RectF(scanWindow);
    }

    @Override
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        updateScanWindow(width, height);
    }

    private void updateScanWindow(int width, int height) {
        if (width == 0 || height == 0) {
            return;
        }

        final float windowWidth;
        final float windowHeight;

        if (scanMode == AppConstants.SCAN_MODE_BARCODE) {
            windowWidth = width * AppConstants.BARCODE_WINDOW_WIDTH_RATIO;
            windowHeight = windowWidth * AppConstants.BARCODE_WINDOW_ASPECT_RATIO;
        } else {
            // QR and DEFAULT share a square window.
            final float side = Math.min(width, height) * AppConstants.QR_WINDOW_SIDE_RATIO;
            windowWidth = side;
            windowHeight = side;
        }

        final float centerX = width / 2f;
        final float centerY = height / 2f;
        scanWindow.set(
                centerX - windowWidth / 2f,
                centerY - windowHeight / 2f,
                centerX + windowWidth / 2f,
                centerY + windowHeight / 2f);

        restartLineAnimator();
    }

    private void restartLineAnimator() {
        stopLineAnimator();

        lineAnimator = ValueAnimator.ofFloat(0f, 1f);
        lineAnimator.setDuration(AppConstants.LINE_ANIMATION_DURATION_MS);
        lineAnimator.setRepeatCount(ValueAnimator.INFINITE);
        lineAnimator.setRepeatMode(ValueAnimator.REVERSE);
        lineAnimator.setInterpolator(new LinearInterpolator());
        lineAnimator.addUpdateListener(animation -> {
            linePosition = (float) animation.getAnimatedValue();
            invalidate();
        });
        lineAnimator.start();
    }

    private void stopLineAnimator() {
        if (lineAnimator != null) {
            lineAnimator.cancel();
            lineAnimator = null;
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        stopLineAnimator();
        super.onDetachedFromWindow();
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        super.onDraw(canvas);

        if (scanWindow.isEmpty()) {
            return;
        }

        drawScrim(canvas);
        drawCorners(canvas);
        drawSweepLine(canvas);
    }

    /**
     * Dims everything outside the scan window using four rectangles. This avoids
     * {@code PorterDuff.Mode.CLEAR}, which needs an offscreen layer and behaves
     * inconsistently above a camera surface.
     */
    private void drawScrim(@NonNull Canvas canvas) {
        final float width = getWidth();
        final float height = getHeight();

        canvas.drawRect(0f, 0f, width, scanWindow.top, scrimPaint);
        canvas.drawRect(0f, scanWindow.bottom, width, height, scrimPaint);
        canvas.drawRect(0f, scanWindow.top, scanWindow.left, scanWindow.bottom, scrimPaint);
        canvas.drawRect(scanWindow.right, scanWindow.top, width, scanWindow.bottom, scrimPaint);
    }

    private void drawCorners(@NonNull Canvas canvas) {
        final float length = Math.min(scanWindow.width(), scanWindow.height())
                * AppConstants.CORNER_LENGTH_RATIO;

        // Top left.
        canvas.drawLine(scanWindow.left, scanWindow.top, scanWindow.left + length, scanWindow.top, cornerPaint);
        canvas.drawLine(scanWindow.left, scanWindow.top, scanWindow.left, scanWindow.top + length, cornerPaint);
        // Top right.
        canvas.drawLine(scanWindow.right, scanWindow.top, scanWindow.right - length, scanWindow.top, cornerPaint);
        canvas.drawLine(scanWindow.right, scanWindow.top, scanWindow.right, scanWindow.top + length, cornerPaint);
        // Bottom left.
        canvas.drawLine(scanWindow.left, scanWindow.bottom, scanWindow.left + length, scanWindow.bottom, cornerPaint);
        canvas.drawLine(scanWindow.left, scanWindow.bottom, scanWindow.left, scanWindow.bottom - length, cornerPaint);
        // Bottom right.
        canvas.drawLine(scanWindow.right, scanWindow.bottom, scanWindow.right - length, scanWindow.bottom, cornerPaint);
        canvas.drawLine(scanWindow.right, scanWindow.bottom, scanWindow.right, scanWindow.bottom - length, cornerPaint);
    }

    private void drawSweepLine(@NonNull Canvas canvas) {
        final float inset = AppUtil.dpToPx(getContext(), AppConstants.LINE_INSET_DP);
        final float y = scanWindow.top + scanWindow.height() * linePosition;
        canvas.drawLine(scanWindow.left + inset, y, scanWindow.right - inset, y, linePaint);
    }
}
