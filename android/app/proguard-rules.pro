# SQLCipher's JNI code looks these classes up by name; R8 must not rename or
# strip them. (sqflite_sqlcipher documents the first rule; sqlcipher-android
# 4.x lives under net.zetetic.)
-keep class net.sqlcipher.** { *; }
-keep class net.zetetic.database.** { *; }
