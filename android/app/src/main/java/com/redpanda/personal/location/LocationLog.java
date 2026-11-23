package com.redpanda.personal.location;

import android.content.Context;
import android.location.Location;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Append-only raw log the Dart side turns into visits and trips. One JSON
 * object per line, one file per local day: {@code location_log/2026-11-23.jsonl}.
 *
 * <ul>
 *   <li>{@code {"k":"p","t":ms,"la":lat,"lo":lng,"ac":m,"sp":m/s}} a location fix</li>
 *   <li>{@code {"k":"a","t":ms,"a":"IN_VEHICLE","e":1}} an activity transition (e=1 enter, 0 exit)</li>
 *   <li>{@code {"k":"s","t":ms,"e":"start"}} recorder started or stopped</li>
 * </ul>
 */
final class LocationLog {
    private LocationLog() {}

    static final String DIR = "location_log";

    static File dir(Context context) {
        File dir = new File(context.getFilesDir(), DIR);
        if (!dir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            dir.mkdirs();
        }
        return dir;
    }

    static void fix(Context context, Location l) {
        StringBuilder b = new StringBuilder(96);
        b.append("{\"k\":\"p\",\"t\":").append(l.getTime());
        b.append(",\"la\":").append(String.format(Locale.US, "%.7f", l.getLatitude()));
        b.append(",\"lo\":").append(String.format(Locale.US, "%.7f", l.getLongitude()));
        if (l.hasAccuracy()) {
            b.append(",\"ac\":").append(String.format(Locale.US, "%.1f", l.getAccuracy()));
        }
        if (l.hasSpeed()) {
            b.append(",\"sp\":").append(String.format(Locale.US, "%.2f", l.getSpeed()));
        }
        b.append('}');
        append(context, l.getTime(), b.toString());
    }

    static void activity(Context context, long timeMs, String activity, boolean enter) {
        append(
            context,
            timeMs,
            "{\"k\":\"a\",\"t\":" + timeMs + ",\"a\":\"" + activity + "\",\"e\":" + (enter ? 1 : 0) + "}"
        );
    }

    static void session(Context context, String event) {
        long now = System.currentTimeMillis();
        append(context, now, "{\"k\":\"s\",\"t\":" + now + ",\"e\":\"" + event + "\"}");
    }

    private static synchronized void append(Context context, long timeMs, String line) {
        String day = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date(timeMs));
        File file = new File(dir(context), day + ".jsonl");
        try (FileWriter writer = new FileWriter(file, true)) {
            writer.write(line);
            writer.write('\n');
        } catch (IOException ignored) {
            // Losing one point is better than crashing the recorder.
        }
    }
}
