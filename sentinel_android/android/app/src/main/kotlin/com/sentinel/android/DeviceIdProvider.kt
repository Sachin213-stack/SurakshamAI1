package com.sentinel.android

import android.content.Context
import android.provider.Settings
import java.util.UUID

object DeviceIdProvider {
    private const val PREFS_NAME = "sentinel_prefs"
    private const val KEY_DEVICE_ID = "device_id"
    // Known buggy ANDROID_ID value reported by Android emulators and some reset devices.
    private const val INVALID_EMULATOR_ANDROID_ID = "9774d56d682e549c"

    fun getOrCreate(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        if (!existing.isNullOrBlank()) {
            return existing
        }

        return synchronized(this) {
            val recheck = prefs.getString(KEY_DEVICE_ID, null)
            if (!recheck.isNullOrBlank()) {
                return@synchronized recheck
            }

            // ANDROID_ID can be null on some devices or profiles.
            val androidId = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ANDROID_ID
            )
            val sanitizedAndroidId = androidId?.takeIf {
                it.isNotBlank() && it != INVALID_EMULATOR_ANDROID_ID
            }
            val deviceId = sanitizedAndroidId ?: UUID.randomUUID().toString()
            // Commit synchronously so callers get a stable ID immediately.
            prefs.edit().putString(KEY_DEVICE_ID, deviceId).commit()
            deviceId
        }
    }
}
