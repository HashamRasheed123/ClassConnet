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

