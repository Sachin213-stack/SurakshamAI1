package com.sentinel.android

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationHelper {

    private const val CHANNEL_FRAUD = "sentinel_fraud"
    private const val CHANNEL_INFO  = "sentinel_info"

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        nm.createNotificationChannel(NotificationChannel(
            CHANNEL_FRAUD, "Fraud Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "High-priority fraud detection alerts"
            enableLights(true)
            lightColor = Color.RED
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 300, 200, 300)
        })

        nm.createNotificationChannel(NotificationChannel(
            CHANNEL_INFO, "Sentinel Status",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Background service status"
        })
    }

    fun showFraudAlert(context: Context, result: AnalysisResult, source: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val tapIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = if (result.score >= 80) "🚨" else "⚠️"
        val title = "$emoji Fraud Detected (Score: ${result.score})"

        val notification = NotificationCompat.Builder(context, CHANNEL_FRAUD)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(result.reasoning)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("From: $source\n\n${result.reasoning}\n\nAction: ${result.action}"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
            .setColor(Color.RED)
            .build()

        nm.notify(System.currentTimeMillis().toInt(), notification)
    }

    fun showCallBlockedAlert(context: Context, result: AnalysisResult, caller: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val notification = NotificationCompat.Builder(context, CHANNEL_FRAUD)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("🚫 Call Blocked — Fraud Detected")
            .setContentText("Call from $caller blocked. Score: ${result.score}/100")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Call from: $caller\nRisk Score: ${result.score}/100\n\n${result.reasoning}"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setColor(Color.RED)
            .build()

        nm.notify(System.currentTimeMillis().toInt(), notification)
    }

    fun buildForegroundNotification(context: Context) =
        NotificationCompat.Builder(context, CHANNEL_INFO)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("🛡️ Sentinel Active")
            .setContentText("Monitoring SMS and calls for fraud...")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
}
