# ML Kit text recognition: only the Latin and Devanagari models are bundled.
# The plugin references the other script models, which are not included.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
