package com.sentinel.android

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*

/**
 * Foreground Service — keeps Sentinel alive in background.
 * Shows persistent "Sentinel Active" notification.
 * Survives app close, runs from boot.
 */
class SentinelBackgroundService : Service() {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createChannels(this)
        startForeground(1, NotificationHelper.buildForegroundNotification(this))
        Log.d("SentinelService", "Background service started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Register device with backend
        scope.launch {
            try {
                val prefs = getSharedPreferences("sentinel_prefs", MODE_PRIVATE)
                val apiUrl = prefs.getString("api_url", "http://10.0.2.2:8000")!!
                val deviceId = prefs.getString("device_id",
                    android.provider.Settings.Secure.getAndroidId(contentResolver))!!
                val fcmToken = prefs.getString("fcm_token", "no_fcm_token") ?: "no_fcm_token"
                val apiKey = prefs.getString("api_key", "") ?: ""

                SentinelApiClient.registerDevice(
                    apiUrl = apiUrl,
                    deviceId = deviceId,
                    fcmToken = fcmToken,
                    appVersion = "1.0.0",
                    apiKey = apiKey
                )
                Log.d("SentinelService", "Device registered with backend")
            } catch (e: Exception) {
                Log.e("SentinelService", "Device registration failed: ${e.message}")
            }
        }

        // Restart if killed
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
