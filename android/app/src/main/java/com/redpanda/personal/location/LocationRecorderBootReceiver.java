package com.redpanda.personal.location;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Restarts recording after a reboot or an app update if it was on. */
public class LocationRecorderBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
            && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
            && !"android.intent.action.QUICKBOOT_POWERON".equals(action)) {
            return;
        }
        if (!LocationRecorderService.isEnabled(context)) return;
        LocationRecorderService.start(context);
    }
}
