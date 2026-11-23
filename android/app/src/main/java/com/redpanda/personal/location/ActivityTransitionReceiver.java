package com.redpanda.personal.location;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import com.google.android.gms.location.ActivityTransition;
import com.google.android.gms.location.ActivityTransitionEvent;
import com.google.android.gms.location.ActivityTransitionResult;
import com.google.android.gms.location.DetectedActivity;

/** Logs walking / cycling / vehicle / still changes and tells the recorder. */
public class ActivityTransitionReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!ActivityTransitionResult.hasResult(intent)) return;
        ActivityTransitionResult result = ActivityTransitionResult.extractResult(intent);
        if (result == null) return;
        long nowMs = System.currentTimeMillis();
        long nowNanos = SystemClock.elapsedRealtimeNanos();
        for (ActivityTransitionEvent event : result.getTransitionEvents()) {
            String name = nameOf(event.getActivityType());
            if (name == null) continue;
            boolean enter =
                event.getTransitionType() == ActivityTransition.ACTIVITY_TRANSITION_ENTER;
            long at = nowMs - (nowNanos - event.getElapsedRealTimeNanos()) / 1_000_000L;
            LocationLog.activity(context, at, name, enter);
            LocationRecorderService service = LocationRecorderService.instance;
            if (service != null) service.onTransition(name, enter);
        }
    }

    private static String nameOf(int type) {
        switch (type) {
            case DetectedActivity.IN_VEHICLE:
                return "IN_VEHICLE";
            case DetectedActivity.ON_BICYCLE:
                return "ON_BICYCLE";
            case DetectedActivity.WALKING:
                return "WALKING";
            case DetectedActivity.RUNNING:
                return "RUNNING";
            case DetectedActivity.STILL:
                return "STILL";
            default:
                return null;
        }
    }
}
