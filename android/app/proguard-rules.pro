# Flutter-specific ProGuard rules to prevent release crashes

# Keep Flutter engine and framework classes
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }

# Keep audio service classes (critical for music apps)
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# Keep media kit classes
-keep class media.kit.** { *; }
-keep class com.alexmercerind.media_kit.** { *; }

# Keep JNI classes (for native libraries)
-keep class dartjni.** { *; }
-keep class dev.dart.jni.** { *; }

# Keep FFmpeg classes
-keep class com.arthenica.ffmpegkit.** { *; }

# Keep GetX classes (state management)
-keep class get.** { *; }

# Keep Hive classes (database)
-keep class hive.** { *; }

# Keep native method classes
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep serialization classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep WebView classes (if using web features)
-keep class android.webkit.** { *; }

# Keep reflection-based classes
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Prevent obfuscation of plugin classes
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep permission handler classes
-keep class com.baseflow.permissionhandler.** { *; }

# Keep path provider classes  
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep file picker classes
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep share plus classes
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep URL launcher classes
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep Google Fonts classes
-keep class io.flutter.plugins.googlemobileads.** { *; }

# Keep dio networking classes
-keep class dio.** { *; }

# Keep cached network image classes
-keep class flutter.moum.cachednetworkimage.** { *; }

# Silence warnings for missing classes
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**