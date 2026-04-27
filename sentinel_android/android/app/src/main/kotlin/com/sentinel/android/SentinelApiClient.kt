package com.sentinel.android

import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

data class AnalysisResult(
    val id: String,
    val score: Int,
    val action: String,
    val reasoning: String,
    val maskedText: String,
    val timestamp: String
)

/**
 * Lightweight HTTP client — no external dependencies needed.
 * Calls the Sentinel FastAPI backend.
 */
object SentinelApiClient {

    fun analyze(
        apiUrl: String,
        text: String,
        type: String = "sms",
        sourceNumber: String? = null,
        deviceId: String = "android_device"
    ): AnalysisResult {
        val url = URL("$apiUrl/analyze")
        val conn = url.openConnection() as HttpURLConnection

        return try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Accept", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 8000
            conn.readTimeout = 10000

            val body = JSONObject().apply {
                put("type", type)
                put("raw_text", text)
                put("device_id", deviceId)
                sourceNumber?.let { put("source_number", it) }
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val responseCode = conn.responseCode
            if (responseCode != 200) {
                throw Exception("HTTP $responseCode from backend")
            }

            val response = conn.inputStream.bufferedReader().readText()
            parseResult(response)

        } finally {
            conn.disconnect()
        }
    }

    fun registerDevice(apiUrl: String, deviceId: String, fcmToken: String, appVersion: String) {
        val url = URL("$apiUrl/device/register")
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 5000

            val body = JSONObject().apply {
                put("device_id", deviceId)
                put("fcm_token", fcmToken)
                put("platform", "android")
                put("app_version", appVersion)
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(body) }
            conn.responseCode // trigger request
        } finally {
            conn.disconnect()
        }
    }

    fun submitFeedback(apiUrl: String, alertId: String, feedback: String, deviceId: String) {
        val url = URL("$apiUrl/alerts/feedback")
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 5000
            val body = JSONObject().apply {
                put("alert_id", alertId)
                put("feedback", feedback)
                put("device_id", deviceId)
            }.toString()
            OutputStreamWriter(conn.outputStream).use { it.write(body) }
            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }

    private fun parseResult(json: String): AnalysisResult {
        val obj = JSONObject(json)
        return AnalysisResult(
            id = obj.optString("id", ""),
            score = obj.getInt("score"),
            action = obj.getString("action"),
            reasoning = obj.getString("reasoning"),
            maskedText = obj.getString("masked_text"),
            timestamp = obj.optString("timestamp", "")
        )
    }
}
