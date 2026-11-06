package com.redpanda.personal;

import android.app.AppOpsManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Process;
import android.provider.Settings;
import java.util.ArrayList;
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

    /** Foreground time per launchable app for each day in [startMs, endMs). */
    private List<Map<String, Object>> queryDailyUsage(long startMs, long endMs) {
        UsageStatsManager usm =
            (UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);
        PackageManager pm = getPackageManager();
        Map<String, String> labels = new HashMap<>();
        List<Map<String, Object>> rows = new ArrayList<>();
        long dayMs = 24L * 60 * 60 * 1000;
        for (long day = startMs; day < endMs; day += dayMs) {
            // Day boundaries shift by an hour across DST; the caller passes local midnights.
            Map<String, UsageStats> stats =
                usm.queryAndAggregateUsageStats(day, Math.min(day + dayMs, endMs));
            for (UsageStats u : stats.values()) {
                long ms = u.getTotalTimeInForeground();
                if (ms <= 0) continue;
                String pkg = u.getPackageName();
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
                    } catch (Exception e) {
                        label = pkg;
                    }
                    labels.put(pkg, label);
                }
                if (label.isEmpty()) continue;
                Map<String, Object> row = new HashMap<>();
                row.put("day", day);
                row.put("package", pkg);
                row.put("label", label);
                row.put("ms", ms);
                rows.add(row);
            }
        }
        return rows;
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
