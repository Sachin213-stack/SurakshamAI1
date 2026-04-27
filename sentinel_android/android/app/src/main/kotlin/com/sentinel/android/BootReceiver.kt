package com.sentinel.android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts Sentinel background service after device reboot.
 * Ensures protection is always active without user intervention.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val serviceIntent = Intent(context, SentinelBackgroundService::class.java)
            context.startForegroundService(serviceIntent)
        }
    }
}
