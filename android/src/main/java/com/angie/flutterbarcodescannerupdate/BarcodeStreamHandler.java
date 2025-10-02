package com.angie.flutterbarcodescannerupdate;

import io.flutter.plugin.common.EventChannel;
import java.util.concurrent.ConcurrentLinkedQueue;

public class BarcodeStreamHandler implements EventChannel.StreamHandler {
    private EventChannel.EventSink events;
    private static final ConcurrentLinkedQueue<String> eventQueue = new ConcurrentLinkedQueue<>();

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        this.events = events;
        while (!eventQueue.isEmpty()) {
            events.success(eventQueue.poll());
        }
    }

    @Override
    public void onCancel(Object arguments) {
        this.events = null;
    }

    public void sendEvent(String barcode) {
        if (events != null) {
            events.success(barcode);
        } else {
            eventQueue.add(barcode);
        }
    }
}
