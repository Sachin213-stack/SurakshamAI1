package com.sentinel.android

import android.content.Context
import android.provider.Settings
import java.util.UUID

object DeviceIdProvider {
    private const val PREFS_NAME = "sentinel_prefs"
    private const val KEY_DEVICE_ID = "device_id"

    fun getOrCreate(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        if (!existing.isNullOrBlank()) {
            return existing
        }

        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        )
        val sanitizedAndroidId = androidId?.takeIf {
            it.isNotBlank() && it != "9774d56d682e549c"
        }
        val deviceId = sanitizedAndroidId ?: UUID.randomUUID().toString()
        prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        return deviceId
    }
}
