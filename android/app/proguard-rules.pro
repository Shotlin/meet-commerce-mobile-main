# ── Flutter ───────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-keepattributes *Annotation*

# ── Razorpay ──────────────────────────────────────────────────
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keep class com.razorpay.** { *; }
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-dontwarn com.razorpay.**

# ── Retrofit ──────────────────────────────────────────────────
-keep class retrofit2.** { *; }
-keepattributes Signature, Exceptions
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn retrofit2.**

# ── OkHttp ────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Gson / JSON ───────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class sun.misc.Unsafe { *; }

# ── Firebase ──────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# FCM background handler
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# ── Hive ──────────────────────────────────────────────────────
-keep class * extends com.hive.** { *; }
-dontwarn com.hive.**

# ── Freezed / JSON serializable ───────────────────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── flutter_secure_storage ────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── local_auth / biometrics ───────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

# ── Geolocator ────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── Image picker / cropper ────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── Lottie / Rive ─────────────────────────────────────────────
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# ── Multidex ──────────────────────────────────────────────────
-keep class androidx.multidex.** { *; }

# ── Google Play Core (Flutter deferred components / split install) ─
# The app does not use deferred components, but Flutter's embedding
# references these classes. Tell R8 to ignore the missing references.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# ── Suppress common warnings ──────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn kotlin.jvm.internal.**
