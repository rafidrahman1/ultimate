package com.redpanda.personal.location;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import com.google.android.gms.location.ActivityRecognition;
import com.google.android.gms.location.ActivityTransition;
import com.google.android.gms.location.ActivityTransitionRequest;
import com.google.android.gms.location.DetectedActivity;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.redpanda.personal.MainActivity;
import java.util.ArrayList;
import java.util.List;

/**
 * Foreground service that records where you are, like Google Maps Timeline
 * does. It writes raw fixes and activity changes to {@link LocationLog}; the
 * app turns those into visits and trips.
 *
 * <p>Battery: while moving it asks for a GPS fix every ~10 s (only when you
 * have moved 10 m); once you have been in one spot for a few minutes it drops
 * to a Wi-Fi/cell fix every 2 minutes until you move again.
 */
public class LocationRecorderService extends Service {
    private static final String PREFS = "location_recorder";
    private static final String KEY_ENABLED = "enabled";
    private static final String CHANNEL_ID = "location_recorder";
    private static final int NOTIFICATION_ID = 7301;

    /** Within this of the anchor point counts as not having moved. */
    private static final float STILL_RADIUS_M = 60f;
    /** No movement for this long switches to the low-power still mode. */
    private static final long STILL_AFTER_MS = 4 * 60_000L;
    /** A still-mode fix further than this from the anchor means you left. */
    private static final float LEFT_RADIUS_M = 150f;

    static volatile LocationRecorderService instance;
    static volatile long lastFixMs;

    private FusedLocationProviderClient fused;
    private LocationCallback callback;
    private PendingIntent transitionsIntent;
    private final Handler handler = new Handler(Looper.getMainLooper());

    private boolean moving = true;
    private boolean updatesRequested = false;
    private Location anchor;
    private long lastMovedMs;
    private String currentActivity;

    // --- Control from the app ---------------------------------------------

    /** Starts recording and remembers it across reboots. False if location isn't granted. */
    public static boolean start(Context context) {
        if (!hasLocationPermission(context)) return false;
        setEnabled(context, true);
        try {
            context.startForegroundService(new Intent(context, LocationRecorderService.class));
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static void stop(Context context) {
        setEnabled(context, false);
        context.stopService(new Intent(context, LocationRecorderService.class));
    }

    public static boolean isEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ENABLED, false);
    }

    public static boolean isRunning() {
        return instance != null;
    }

    public static long lastFixMs() {
        return lastFixMs;
    }

    public static String logDir(Context context) {
        return LocationLog.dir(context).getAbsolutePath();
    }

    private static void setEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static boolean hasLocationPermission(Context context) {
        return context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
            || context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    // --- Service lifecycle ----------------------------------------------------

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        fused = LocationServices.getFusedLocationProviderClient(this);
        callback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult result) {
                for (Location location : result.getLocations()) onFix(location);
            }
        };
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (!hasLocationPermission(this)) {
            stopSelf();
            return START_NOT_STICKY;
        }
        try {
            startInForeground();
        } catch (Exception e) {
            // Android refuses a location foreground service without permission.
            stopSelf();
            return START_NOT_STICKY;
        }
        if (!updatesRequested) {
            LocationLog.session(this, "start");
            lastMovedMs = System.currentTimeMillis();
            requestLocationUpdates();
            requestActivityTransitions();
            handler.postDelayed(stillCheck, 60_000L);
            updatesRequested = true;
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        if (fused != null && callback != null) fused.removeLocationUpdates(callback);
        if (transitionsIntent != null) {
            try {
                ActivityRecognition.getClient(this).removeActivityTransitionUpdates(transitionsIntent);
            } catch (Exception ignored) {
                // Already gone.
            }
        }
        LocationLog.session(this, "stop");
        instance = null;
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    // --- Location -------------------------------------------------------------

    private void requestLocationUpdates() {
        LocationRequest request = moving
            ? new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
                .setMinUpdateIntervalMillis(5_000L)
                .setMinUpdateDistanceMeters(10f)
                .build()
            : new LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 120_000L)
                .setMinUpdateIntervalMillis(60_000L)
                .build();
        try {
            fused.removeLocationUpdates(callback);
            fused.requestLocationUpdates(request, callback, Looper.getMainLooper());
        } catch (SecurityException e) {
            stopSelf();
        }
    }

    private void onFix(Location location) {
        lastFixMs = location.getTime();
        LocationLog.fix(this, location);

        if (anchor == null) {
            anchor = location;
            lastMovedMs = location.getTime();
            return;
        }
        float distance = anchor.distanceTo(location);
        if (moving) {
            if (distance > STILL_RADIUS_M) {
                anchor = location;
                lastMovedMs = location.getTime();
            }
        } else {
            boolean accurate = !location.hasAccuracy() || location.getAccuracy() < 100f;
            boolean fast = location.hasSpeed() && location.getSpeed() > 3f;
            if ((accurate && distance > LEFT_RADIUS_M) || fast) {
                anchor = location;
                lastMovedMs = location.getTime();
                setMoving(true);
            }
        }
    }

    /** In moving mode no fix arrives while you stand still (10 m filter), so poll. */
    private final Runnable stillCheck = new Runnable() {
        @Override
        public void run() {
            boolean activityMoving = currentActivity != null && !"STILL".equals(currentActivity);
            if (moving
                && !activityMoving
                && System.currentTimeMillis() - lastMovedMs > STILL_AFTER_MS) {
                setMoving(false);
            }
            handler.postDelayed(this, 60_000L);
        }
    };

    private void setMoving(boolean value) {
        if (moving == value) return;
        moving = value;
        updateNotification();
        requestLocationUpdates();
    }

    // --- Activity recognition -----------------------------------------------

    private void requestActivityTransitions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
            && checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)
                != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        List<ActivityTransition> transitions = new ArrayList<>();
        int[] types = {
            DetectedActivity.IN_VEHICLE,
            DetectedActivity.ON_BICYCLE,
            DetectedActivity.WALKING,
            DetectedActivity.RUNNING,
            DetectedActivity.STILL,
        };
        for (int type : types) {
            transitions.add(new ActivityTransition.Builder()
                .setActivityType(type)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build());
            transitions.add(new ActivityTransition.Builder()
                .setActivityType(type)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                .build());
        }
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags |= PendingIntent.FLAG_MUTABLE;
        transitionsIntent = PendingIntent.getBroadcast(
            this,
            0,
            new Intent(this, ActivityTransitionReceiver.class),
            flags
        );
        try {
            ActivityRecognition.getClient(this).requestActivityTransitionUpdates(
                new ActivityTransitionRequest(transitions),
                transitionsIntent
            );
        } catch (SecurityException ignored) {
            // Recording still works from location alone.
        }
    }

    /** Called by {@link ActivityTransitionReceiver} in this process. */
    void onTransition(String activity, boolean enter) {
        if (enter) {
            currentActivity = activity;
            if ("STILL".equals(activity)) {
                setMoving(false);
            } else {
                lastMovedMs = System.currentTimeMillis();
                setMoving(true);
            }
        } else if (activity.equals(currentActivity)) {
            currentActivity = null;
        }
    }

    // --- Notification ---------------------------------------------------------

    private void startInForeground() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Timeline recording",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Shown while the app records your location timeline.");
            channel.setShowBadge(false);
            manager.createNotificationChannel(channel);
        }
        Notification notification = buildNotification();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            );
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private void updateNotification() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        manager.notify(NOTIFICATION_ID, buildNotification());
    }

    private Notification buildNotification() {
        Intent open = new Intent(this, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent content = PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        return new Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Recording your timeline")
            .setContentText(moving ? "On the move" : "Staying put")
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(content)
            .build();
    }
}
