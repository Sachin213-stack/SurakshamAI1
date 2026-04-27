package com.sentinel.android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * SMS BroadcastReceiver
 * Automatically intercepts every incoming SMS and sends it to Sentinel backend.
 * User doesn't need to do anything — runs silently in background.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SentinelSMS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        // Combine multi-part SMS
        val sender = messages[0].originatingAddress ?: "Unknown"
        val body = messages.joinToString("") { it.messageBody }

        Log.d(TAG, "SMS received from: $sender")

        // Send to backend in background coroutine (non-blocking)
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prefs = context.getSharedPreferences("sentinel_prefs", Context.MODE_PRIVATE)
                val deviceId = prefs.getString("device_id", android.provider.Settings.Secure.getAndroidId(context.contentResolver))
                val apiUrl = prefs.getString("api_url", "http://10.0.2.2:8000") // 10.0.2.2 = localhost for emulator

                val result = SentinelApiClient.analyze(
                    apiUrl = apiUrl!!,
                    text = body,
                    type = "sms",
                    sourceNumber = sender,
                    deviceId = deviceId!!
                )

                Log.d(TAG, "Analysis result: score=${result.score}, action=${result.action}")

                // Trigger overlay if fraud detected
                if (result.score >= 50) {
                    showFraudAlert(context, result, sender)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to analyze SMS: ${e.message}")
            }
        }
    }

    private fun showFraudAlert(context: Context, result: AnalysisResult, sender: String) {
        // Show notification
        NotificationHelper.showFraudAlert(context, result, sender)

        // Show overlay for high-risk
        if (result.score >= 80) {
            val overlayIntent = Intent(context, OverlayAlertActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("score", result.score)
                putExtra("action", result.action)
                putExtra("reasoning", result.reasoning)
                putExtra("masked_text", result.maskedText)
                putExtra("source", sender)
                putExtra("type", "SMS")
            }
            context.startActivity(overlayIntent)
        }
    }
}
