package com.redpanda.personal;

import android.net.Uri;
import android.provider.DocumentsContract;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.redpanda.personal/document_io";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
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
