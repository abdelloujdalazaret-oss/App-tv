# media_kit / libmpv : ne pas obfusquer les classes natives
-keep class com.alexmercerind.** { *; }
-keep class org.jetbrains.** { *; }
-dontwarn com.alexmercerind.**
-keep class io.flutter.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**
