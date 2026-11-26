# Proguard rules for Flutter release build
# Keeps native plugin bindings for printing, pdf, image_picker, and flutter core
-keep class printing.** { *; }
-keep class pdf.** { *; }
-keep class com.tekartik.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn printing.**
-dontwarn pdf.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# SharedPreferences Kotlin JNI & Coroutines support (prevents NoSuchMethodError in SharedPreferencesApiRegistrar.getAll)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }

# ---------------------------------------------------------------------------
# flutter_local_notifications: scheduled lecture alarms are serialized with Gson.
# R8 strips generic signatures by default -> "Missing type parameter" and the
# alarm is never scheduled / re-scheduled after reboot in RELEASE builds.
# ---------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**

# Custom MainActivity method channel
-keep class com.softwareclass.softwareclass.** { *; }

