package com.sentinel.android

import android.telecom.Call
import android.telecom.CallScreeningService
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

/**
 * Call Screening Service — "Block with Override" model
 *
 * Score < 50  → Allow silently
 * Score 50-80 → Allow + show warning notification
 * Score > 80  → HOLD call + show CallDecisionActivity (5s countdown)
 *               User can Allow or Block manually
 *               If no action → auto block after countdown
 */
class SentinelCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "SentinelCall"
        // Shared between service and decision activity
        var pendingCallDetails: Call.Details? = null
        var pendingService: SentinelCallScreeningService? = null
        var pendingResult: AnalysisResult? = null
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val callerNumber = callDetails.handle?.schemeSpecificPart ?: "Unknown"
        Log.d(TAG, "Screening call from: $callerNumber")

        val prefs = getSharedPreferences("sentinel_prefs", MODE_PRIVATE)
        val apiUrl   = prefs.getString("api_url", "http://10.0.2.2:8000")!!
        val deviceId = prefs.getString("device_id",
            android.provider.Settings.Secure.getAndroidId(contentResolver))!!
        val apiKey = prefs.getString("api_key", "")

        val result = runBlocking(Dispatchers.IO) {
            try {
                SentinelApiClient.analyze(
                    apiUrl = apiUrl,
                    text = "Incoming call from: $callerNumber",
                    type = "call_transcript",
                    sourceNumber = callerNumber,
                    deviceId = deviceId,
                    apiKey = apiKey
                )
            } catch (e: Exception) {
                Log.e(TAG, "Screening failed: ${e.message}")
                null
            }
        }

        when {
            // ── High risk: show decision overlay, hold call ────────────────
            result != null && result.score >= 80 -> {
                Log.w(TAG, "HIGH RISK call — showing decision screen. Score: ${result.score}")

                // Store refs so CallDecisionActivity can respond
                pendingCallDetails = callDetails
                pendingService     = this
                pendingResult      = result

                // Launch decision activity (user gets 5s to Allow or Block)
                val intent = Intent(this, CallDecisionActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("score",       result.score)
                    putExtra("action",      result.action)
                    putExtra("reasoning",   result.reasoning)
                    putExtra("masked_text", result.maskedText)
                    putExtra("caller",      callerNumber)
                }
                startActivity(intent)

                // HOLD — do NOT respond yet; CallDecisionActivity will call
                // respondToCall() via allowCall() / blockCall() below
            }

            // ── Medium risk: allow but warn ────────────────────────────────
            result != null && result.score >= 50 -> {
                Log.i(TAG, "MEDIUM RISK call — allowing with warning. Score: ${result.score}")
                NotificationHelper.showFraudAlert(this, result, callerNumber)
                respondToCall(callDetails, CallResponse.Builder().setRejectCall(false).build())
            }

            // ── Low risk / error: allow silently ──────────────────────────
            else -> {
                respondToCall(callDetails, CallResponse.Builder().setRejectCall(false).build())
            }
        }
    }

    /** Called by CallDecisionActivity when user taps "Allow" */
    fun allowCall() {
        val details = pendingCallDetails ?: return
        Log.i(TAG, "User ALLOWED the call (false positive override)")
        respondToCall(details, CallResponse.Builder().setRejectCall(false).build())

        // Store as false positive for model improvement
        pendingResult?.let { result ->
            val prefs = getSharedPreferences("sentinel_prefs", MODE_PRIVATE)
            val apiUrl   = prefs.getString("api_url", "http://10.0.2.2:8000")!!
            val deviceId = prefs.getString("device_id", "android")!!
            val apiKey = prefs.getString("api_key", "")
            Thread {
                try { SentinelApiClient.submitFeedback(apiUrl, result.id, "false_positive", deviceId, apiKey) }
                catch (e: Exception) { Log.e(TAG, "Feedback failed: ${e.message}") }
            }.start()
        }
        clearPending()
    }

    /** Called by CallDecisionActivity when user taps "Block" or countdown expires */
    fun blockCall() {
        val details = pendingCallDetails ?: return
        val result = pendingResult ?: run {
            Log.e(TAG, "No pending result found while blocking call")
            respondToCall(details, CallResponse.Builder()
                .setRejectCall(true)
                .setSkipCallLog(false)
                .build())
            clearPending()
            return
        }
        Log.w(TAG, "Call BLOCKED by user/timeout")
        NotificationHelper.showCallBlockedAlert(this, result, "Unknown")
        respondToCall(details, CallResponse.Builder()
            .setRejectCall(true)
            .setSkipCallLog(false)
            .build())
        clearPending()
    }

    private fun clearPending() {
        pendingCallDetails = null
        pendingService     = null
        pendingResult      = null
    }
}
