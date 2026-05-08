# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Keep app classes
-keep class com.medcasespro.med.** { *; }

# Shared preferences
-keep class androidx.preference.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# General Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
