# Prevent Razorpay classes from being removed
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Prevent missing annotation issues
-keep class proguard.annotation.** { *; }
-dontwarn proguard.annotation.**

# Optional: keep Flutter and plugin entry points
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
