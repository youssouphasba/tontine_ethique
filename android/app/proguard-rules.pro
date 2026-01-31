# Stripe ProGuard Rules
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }
-keep interface com.stripe.android.** { *; }

# For 3DS2
-dontwarn com.stripe.android.stripe3ds2.**
-keep class com.stripe.android.stripe3ds2.** { *; }

# Material Components interaction
-dontwarn com.google.android.material.**
-keep class com.google.android.material.** { *; }

# View Binding (Stripe UI uses it)
-keep class androidx.databinding.** { *; }

# Retrofit / OkHttp (used internally by some Stripe components)
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-keepattributes Signature
-keepattributes *Annotation*
