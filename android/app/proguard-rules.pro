# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Hive
-keep class com.hivedb.** { *; }

# Blue Plus
-keep class com.boskokg.flutter_blue_plus.** { *; }

# Play Store Core (for deferred components if not used)
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.assetpacks.**

# ML Kit (Exclude missing optional language models)
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Printer & Hardware
-keep class com.example.flutter_thermal_printer.** { *; }
-dontwarn com.example.flutter_thermal_printer.**
-keep class com.github.danielfelix.** { *; }
-keep class com.sun.jna.** { *; } # common in native libs
-dontwarn com.sun.jna.**

# General hardware/serial
-keep class com.hoho.android.usbserial.** { *; }
-dontwarn com.hoho.android.usbserial.**

# Common missing annotations/warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.j2objc.annotations.**
-dontwarn sun.misc.Unsafe

# BizPOS Models & Entities
# Note: Keep the app's main package to prevent stripping of custom Android/Kotlin code
-keep class com.biztonic.pos.** { *; }
-keep class lib.models.** { *; } # Many models are in lib/models in Flutter

# Keep specific serialization methods used by plugins/reflection
-keepclassmembers class * {
  *** fromMap(...);
  *** toMap(...);
  *** fromJson(...);
  *** toJson(...);
}

# Hive Persistence - Keep all adapters and objects
-keep class com.hivedb.** { *; }
-keep class * extends com.hivedb.HiveObject { *; }
-keep class * implements com.hivedb.TypeAdapter { *; }
-keep @com.hivedb.annotations.HiveType class * { *; }
-keepclassmembers class * {
    @com.hivedb.annotations.HiveField <fields>;
}

# Firebase / Firestore (Standard rules)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Plugin specific keeps
-keep class io.flutter.plugins.** { *; }
-keep class com.boskokg.flutter_blue_plus.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.example.flutter_thermal_printer.** { *; }

# Common missing annotations/warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.j2objc.annotations.**
-dontwarn sun.misc.Unsafe
