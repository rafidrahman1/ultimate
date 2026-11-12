package com.redpanda.personal;

import android.app.AppOpsManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Process;
import android.provider.Settings;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import android.provider.DocumentsContract;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.redpanda.personal/document_io";
    private static final String USAGE_CHANNEL = "com.redpanda.personal/usage_stats";

    private boolean hasUsageAccess() {
        AppOpsManager ops = (AppOpsManager) getSystemService(Context.APP_OPS_SERVICE);
        int mode = ops.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            getPackageName()
        );
        return mode == AppOpsManager.MODE_ALLOWED;
    }

    /**
     * Foreground time per launchable app for each local day in [startMs, endMs),
     * built from activity events (like Digital Wellbeing) and clipped to day
     * boundaries. queryAndAggregateUsageStats returns whole buckets that overlap
     * the range, which over-counts.
     */
    private List<Map<String, Object>> queryDailyUsage(long startMs, long endMs) {
        UsageStatsManager usm =
            (UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);
        PackageManager pm = getPackageManager();

        // Local-midnight day starts (DST-safe); the caller passes a local midnight.
        List<Long> dayStarts = new ArrayList<>();
        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(startMs);
        while (cal.getTimeInMillis() < endMs) {
            dayStarts.add(cal.getTimeInMillis());
            cal.add(Calendar.DAY_OF_MONTH, 1);
        }
        if (dayStarts.isEmpty()) return new ArrayList<>();
        long rangeEnd = Math.min(endMs, System.currentTimeMillis());

        // package -> (day index -> ms)
        Map<String, long[]> totals = new HashMap<>();
        // package/class -> resume time of the activity currently in foreground
        Map<String, Long> open = new HashMap<>();

        UsageEvents events = usm.queryEvents(startMs, endMs);
        UsageEvents.Event e = new UsageEvents.Event();
        while (events.hasNextEvent()) {
            events.getNextEvent(e);
            int type = e.getEventType();
            String pkg = e.getPackageName();
            long ts = e.getTimeStamp();
            if (type == UsageEvents.Event.ACTIVITY_RESUMED) {
                open.put(pkg + "/" + e.getClassName(), ts);
            } else if (type == UsageEvents.Event.ACTIVITY_PAUSED
                || type == UsageEvents.Event.ACTIVITY_STOPPED) {
                Long from = open.remove(pkg + "/" + e.getClassName());
                if (from != null) addInterval(totals, dayStarts, pkg, from, ts, rangeEnd);
            } else if (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE
                || type == UsageEvents.Event.DEVICE_SHUTDOWN) {
                closeAll(open, totals, dayStarts, ts, rangeEnd);
            }
        }
        closeAll(open, totals, dayStarts, rangeEnd, rangeEnd);

        Map<String, String> labels = new HashMap<>();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<String, long[]> entry : totals.entrySet()) {
            String pkg = entry.getKey();
            String label = labels.get(pkg);
            if (label == null) {
                if (pm.getLaunchIntentForPackage(pkg) == null) {
                    labels.put(pkg, "");
                    continue;
                }
                try {
                    label = pm.getApplicationLabel(
                        pm.getApplicationInfo(pkg, 0)
                    ).toString();
                } catch (Exception ex) {
                    label = pkg;
                }
                labels.put(pkg, label);
            }
            if (label.isEmpty()) continue;
            long[] perDay = entry.getValue();
            for (int i = 0; i < perDay.length; i++) {
                if (perDay[i] <= 0) continue;
                Map<String, Object> row = new HashMap<>();
                row.put("day", dayStarts.get(i));
                row.put("package", pkg);
                row.put("label", label);
                row.put("ms", perDay[i]);
                rows.add(row);
            }
        }
        return rows;
    }

    /** Phone days turn over at this hour, so late-night use stays with its evening. */
    private static final int PHONE_DAY_START_HOUR = 4;

    /**
     * Pickups and the first and last use for each phone day starting on a local
     * day in [startMs, endMs). A phone day runs from 04:00 to 04:00. Pickups are
     * unlocks; on a phone with no lock screen they are screen-ons instead.
     */
    private List<Map<String, Object>> queryPhoneDays(long startMs, long endMs) {
        UsageStatsManager usm =
            (UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);

        List<Long> midnights = new ArrayList<>();
        List<Long> windows = new ArrayList<>();
        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(startMs);
        while (cal.getTimeInMillis() < endMs) {
            midnights.add(cal.getTimeInMillis());
            Calendar w = (Calendar) cal.clone();
            w.set(Calendar.HOUR_OF_DAY, PHONE_DAY_START_HOUR);
            windows.add(w.getTimeInMillis());
            cal.add(Calendar.DAY_OF_MONTH, 1);
        }
        int n = midnights.size();
        if (n == 0) return new ArrayList<>();
        Calendar last = (Calendar) cal.clone();
        last.set(Calendar.HOUR_OF_DAY, PHONE_DAY_START_HOUR);
        windows.add(last.getTimeInMillis());

        int[] unlocks = new int[n];
        int[] screenOns = new int[n];
        long[] firstUnlock = new long[n];
        long[] firstOn = new long[n];
        long[] lastOffUnlocked = new long[n];
        long[] lastOff = new long[n];

        long from = windows.get(0);
        long to = Math.min(windows.get(n), System.currentTimeMillis());
        if (to <= from) return new ArrayList<>();
        UsageEvents events = usm.queryEvents(from, to);
        UsageEvents.Event e = new UsageEvents.Event();
        int day = 0;
        boolean unlocked = false;
        while (events.hasNextEvent()) {
            events.getNextEvent(e);
            long ts = e.getTimeStamp();
            if (ts < from) continue;
            while (day < n - 1 && ts >= windows.get(day + 1)) day++;
            int type = e.getEventType();
            if (type == UsageEvents.Event.KEYGUARD_HIDDEN) {
                unlocks[day]++;
                if (firstUnlock[day] == 0) firstUnlock[day] = ts;
                unlocked = true;
            } else if (type == UsageEvents.Event.SCREEN_INTERACTIVE) {
                screenOns[day]++;
                if (firstOn[day] == 0) firstOn[day] = ts;
            } else if (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE) {
                lastOff[day] = ts;
                if (unlocked) lastOffUnlocked[day] = ts;
                unlocked = false;
            }
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            boolean locks = unlocks[i] > 0;
            int pickups = locks ? unlocks[i] : screenOns[i];
            if (pickups <= 0) continue;
            long first = locks ? firstUnlock[i] : firstOn[i];
            long lastUse = locks && lastOffUnlocked[i] > 0 ? lastOffUnlocked[i] : lastOff[i];
            Map<String, Object> row = new HashMap<>();
            row.put("day", midnights.get(i));
            row.put("pickups", pickups);
            row.put("firstMs", first);
            row.put("lastMs", lastUse);
            // False while the phone day is still running.
            row.put("complete", windows.get(i + 1) <= to);
            rows.add(row);
        }
        return rows;
    }

    private void closeAll(
        Map<String, Long> open,
        Map<String, long[]> totals,
        List<Long> dayStarts,
        long ts,
        long rangeEnd
    ) {
        for (Map.Entry<String, Long> o : open.entrySet()) {
            String pkg = o.getKey().substring(0, o.getKey().indexOf('/'));
            addInterval(totals, dayStarts, pkg, o.getValue(), ts, rangeEnd);
        }
        open.clear();
    }

    /** Adds [from, to) to [pkg]'s per-day totals, split at day boundaries. */
    private void addInterval(
        Map<String, long[]> totals,
        List<Long> dayStarts,
        String pkg,
        long from,
        long to,
        long rangeEnd
    ) {
        to = Math.min(to, rangeEnd);
        if (to <= from) return;
        long[] perDay = totals.get(pkg);
        if (perDay == null) {
            perDay = new long[dayStarts.size()];
            totals.put(pkg, perDay);
        }
        for (int i = 0; i < dayStarts.size(); i++) {
            long dayStart = dayStarts.get(i);
            long dayEnd = i + 1 < dayStarts.size()
                ? dayStarts.get(i + 1)
                : Long.MAX_VALUE;
            long a = Math.max(from, dayStart);
            long b = Math.min(to, dayEnd);
            if (b > a) perDay[i] += b - a;
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            USAGE_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "hasAccess":
                    result.success(hasUsageAccess());
                    break;
                case "openSettings":
                    Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    try {
                        startActivity(intent);
                    } catch (Exception e) {
                        startActivity(new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS));
                    }
                    result.success(null);
                    break;
                case "queryDaily":
                    Number start = call.argument("startMs");
                    Number end = call.argument("endMs");
                    if (start == null || end == null || !hasUsageAccess()) {
                        result.success(new ArrayList<>());
                        break;
                    }
                    new Thread(() -> {
                        List<Map<String, Object>> rows =
                            queryDailyUsage(start.longValue(), end.longValue());
                        runOnUiThread(() -> result.success(rows));
                    }).start();
                    break;
                case "queryPhoneDays":
                    Number phoneStart = call.argument("startMs");
                    Number phoneEnd = call.argument("endMs");
                    if (phoneStart == null || phoneEnd == null || !hasUsageAccess()) {
                        result.success(new ArrayList<>());
                        break;
                    }
                    new Thread(() -> {
                        List<Map<String, Object>> rows = queryPhoneDays(
                            phoneStart.longValue(),
                            phoneEnd.longValue()
                        );
                        runOnUiThread(() -> result.success(rows));
                    }).start();
                    break;
                default:
                    result.notImplemented();
            }
        });
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"deleteDocument".equals(call.method)) {
                result.notImplemented();
                return;
            }

            String uriString = call.argument("uri");
            if (uriString == null) {
                result.success(false);
                return;
            }

            try {
                Uri uri = Uri.parse(uriString);
                boolean deleted = DocumentsContract.deleteDocument(
                    getContentResolver(),
                    uri
                );
                result.success(deleted);
            } catch (Exception e) {
                result.success(false);
            }
        });
    }
}
