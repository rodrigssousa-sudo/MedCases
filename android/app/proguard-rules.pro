# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── App classes ──────────────────────────────────────────────────────────────
-keep class com.medcasespro.med.** { *; }

# ─── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keepclassmembers class **$WhenMappings { <fields>; }
-dontwarn kotlin.**

# ─── Firebase Core ────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Firebase Auth ────────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ─── Firestore ────────────────────────────────────────────────────────────────
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firestore.**

# ─── Google Sign-In ───────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ─── Firebase Storage ─────────────────────────────────────────────────────────
-keep class com.google.firebase.storage.** { *; }

# ─── OkHttp / Retrofit (usado internamente pelo Firebase) ─────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ─── Shared Preferences ───────────────────────────────────────────────────────
-keep class androidx.preference.** { *; }
-keep class androidx.datastore.** { *; }

# ─── share_plus ───────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ─── file_picker ──────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ─── url_launcher ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ─── flutter_tts ──────────────────────────────────────────────────────────────
-keep class com.tundralabs.fluttertts.** { *; }

# ─── Google Play Core (necessário para minify com Firebase) ───────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ─── Debugging: preserva nomes de classes e linha nos stack traces ─────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
