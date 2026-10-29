# Horizon Launcher ProGuard Rules
-keep class dev.playhorizon.launcher.core.HorizonNativeBridge { *; }
-keepclassmembers class * {
    native <methods>;
}
