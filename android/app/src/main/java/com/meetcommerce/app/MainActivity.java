package com.meetcommerce.app;

import android.os.Build;
import android.view.WindowManager;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

public class MainActivity extends FlutterFragmentActivity {
    private static final String SECURITY_CHANNEL = "bakaloo/security";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SECURITY_CHANNEL)
            .setMethodCallHandler(
                (MethodCall call, MethodChannel.Result result) -> {
                    switch (call.method) {
                        case "enableSecure":
                            runOnUiThread(
                                () -> {
                                    getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                                    result.success(null);
                                }
                            );
                            break;
                        case "disableSecure":
                            runOnUiThread(
                                () -> {
                                    getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                                    result.success(null);
                                }
                            );
                            break;
                        case "isDeviceCompromised":
                            result.success(isDeviceCompromised());
                            break;
                        default:
                            result.notImplemented();
                    }
                }
            );
    }

    private boolean isDeviceCompromised() {
        final boolean hasTestKeys = Build.TAGS != null && Build.TAGS.contains("test-keys");
        final String[] suPaths = {
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
        };

        boolean hasSuBinary = false;
        for (String path : suPaths) {
            if (new File(path).exists()) {
                hasSuBinary = true;
                break;
            }
        }

        boolean hasSuInPath = false;
        Process process = null;
        try {
            process = Runtime.getRuntime().exec(new String[] {"/system/xbin/which", "su"});
            try (BufferedReader reader =
                new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                hasSuInPath = reader.readLine() != null;
            }
        } catch (Throwable ignored) {
            hasSuInPath = false;
        } finally {
            if (process != null) {
                process.destroy();
            }
        }

        return hasTestKeys || hasSuBinary || hasSuInPath;
    }
}
