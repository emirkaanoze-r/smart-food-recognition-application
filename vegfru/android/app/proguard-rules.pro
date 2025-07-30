# Keep TensorFlow Lite GPU classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep TFLite GPU delegate and options
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**