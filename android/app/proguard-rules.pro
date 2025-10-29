-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class com.google.crypto.tink.** {
    *;
}

-keep class com.google.errorprone.annotations.** { *; }
-keep class javax.annotation.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep your model classes
-keep class com.example.lagfrontend.models.** { *; }

# Prevent proguard from stripping interface information from TypeAdapter
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# General Android rules
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}