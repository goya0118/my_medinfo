# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# TensorFlow Lite GPU Delegate
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory** { *; }

# ML Kit 관련
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# 일반적인 규칙
-dontwarn org.tensorflow.lite.**
-dontwarn com.google.android.gms.**