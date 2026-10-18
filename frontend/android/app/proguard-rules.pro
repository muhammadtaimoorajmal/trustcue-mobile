# Flutter Wrapper & Play Core deferred components
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn com.google.android.play.core.**


# Google ML Kit Text Recognition and Barcode Scanning
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# AndroidX Security / EncryptedSharedPreferences (flutter_secure_storage)
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# SQLite / Sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Protocol Buffers / Google Play Services
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Keep generic annotations and attributes needed for reflection/serialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
