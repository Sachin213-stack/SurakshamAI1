package com.sentinel.android

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.*

/**
 * Full-screen Red Overlay Alert
 * Appears on top of everything (including lock screen) when fraud is detected.
 * Non-clickable background prevents accidental taps on phishing links.
 */
class OverlayAlertActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make it show over lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        val score   = intent.getIntExtra("score", 0)
        val action  = intent.getStringExtra("action") ?: "BLOCK_CALL"
        val reason  = intent.getStringExtra("reasoning") ?: ""
        val masked  = intent.getStringExtra("masked_text") ?: ""
        val source  = intent.getStringExtra("source") ?: "Unknown"
        val type    = intent.getStringExtra("type") ?: "SMS"

        // ── Build UI programmatically ──────────────────────────────────────
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#CC0D0D0D"))
            setPadding(40, 60, 40, 60)
        }

        // Red border overlay effect
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1A1A1A"))
            setPadding(32, 32, 32, 32)
        }
        card.background = resources.getDrawable(android.R.drawable.dialog_holo_dark_frame, null)

        // Shield icon + title
        val title = TextView(this).apply {
            text = "🛡️ FRAUD DETECTED"
            textSize = 22f
            setTextColor(Color.parseColor("#EF4444"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 8)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

        // Score badge
        val scoreBadge = TextView(this).apply {
            text = "Risk Score: $score / 100"
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }

        // Action label
        val actionColor = if (action == "BLOCK_CALL") "#EF4444" else "#F59E0B"
        val actionLabel = TextView(this).apply {
            text = "⚡ $action"
            textSize = 14f
            setTextColor(Color.parseColor(actionColor))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }

        // Source info
        val sourceInfo = TextView(this).apply {
            text = "$type from: $source"
            textSize = 12f
            setTextColor(Color.parseColor("#9CA3AF"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }

        // Reasoning
        val reasonText = TextView(this).apply {
            text = "⚠️ $reason"
            textSize = 13f
            setTextColor(Color.parseColor("#D1D5DB"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }

        // Masked text
        val maskedLabel = TextView(this).apply {
            text = "Masked Content:\n$masked"
            textSize = 11f
            setTextColor(Color.parseColor("#6B7280"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        // Dismiss button
        val dismissBtn = Button(this).apply {
            text = "I Understand — Dismiss"
            setBackgroundColor(Color.parseColor("#374151"))
            setTextColor(Color.WHITE)
            setOnClickListener { finish() }
        }

        // Report false positive
        val falsePositiveBtn = Button(this).apply {
            text = "Mark as Safe (False Positive)"
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.parseColor("#6B7280"))
            setOnClickListener {
                // TODO: call POST /alerts/feedback
                finish()
            }
        }

        card.addView(title)
        card.addView(scoreBadge)
        card.addView(actionLabel)
        card.addView(sourceInfo)
        card.addView(reasonText)
        card.addView(maskedLabel)
        card.addView(dismissBtn)
        card.addView(falsePositiveBtn)
        root.addView(card)

        setContentView(root)

        // Auto-dismiss after 30 seconds
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 30000)
    }
}
