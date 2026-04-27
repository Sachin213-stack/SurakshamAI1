package com.sentinel.android

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.*

/**
 * CallDecisionActivity — "Block with Override" UI
 *
 * Shown when an incoming call scores > 80 (high fraud risk).
 * User has 5 seconds to manually Allow or Block.
 * If no action → auto-block.
 *
 * This solves the false-positive problem:
 * Genuine calls can still be allowed by the user.
 */
class CallDecisionActivity : Activity() {

    private var countDownTimer: CountDownTimer? = null
    private val COUNTDOWN_MS = 5000L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON   or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        val score     = intent.getIntExtra("score", 0)
        val action    = intent.getStringExtra("action") ?: "BLOCK_CALL"
        val reasoning = intent.getStringExtra("reasoning") ?: ""
        val masked    = intent.getStringExtra("masked_text") ?: ""
        val caller    = intent.getStringExtra("caller") ?: "Unknown"

        // ── Root layout ───────────────────────────────────────────────────
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E6000000"))
            setPadding(32, 48, 32, 48)
        }

        // ── Warning icon ──────────────────────────────────────────────────
        val icon = TextView(this).apply {
            text     = "⚠️"
            textSize = 52f
            gravity  = Gravity.CENTER
            setPadding(0, 0, 0, 8)
        }

        // ── Title ─────────────────────────────────────────────────────────
        val title = TextView(this).apply {
            text     = "Suspicious Call Detected"
            textSize = 20f
            setTextColor(Color.parseColor("#F59E0B"))
            gravity  = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 4)
        }

        // ── Caller ────────────────────────────────────────────────────────
        val callerTv = TextView(this).apply {
            text     = "From: $caller"
            textSize = 13f
            setTextColor(Color.parseColor("#9CA3AF"))
            gravity  = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }

        // ── Score ─────────────────────────────────────────────────────────
        val scoreTv = TextView(this).apply {
            text     = "Risk Score: $score / 100"
            textSize = 16f
            setTextColor(Color.parseColor("#EF4444"))
            gravity  = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 12)
        }

        // ── Reasoning card ────────────────────────────────────────────────
        val reasonCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1F2937"))
            setPadding(20, 14, 20, 14)
        }
        val reasonTv = TextView(this).apply {
            text     = "🤖 $reasoning"
            textSize = 12f
            setTextColor(Color.parseColor("#D1D5DB"))
            gravity  = Gravity.CENTER
        }
        reasonCard.addView(reasonTv)

        // ── Countdown bar ─────────────────────────────────────────────────
        val countdownTv = TextView(this).apply {
            text     = "Auto-blocking in 5s..."
            textSize = 12f
            setTextColor(Color.parseColor("#6B7280"))
            gravity  = Gravity.CENTER
            setPadding(0, 16, 0, 8)
        }

        val progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max      = 100
            progress = 100
            setPadding(0, 0, 0, 20)
        }

        // ── Buttons ───────────────────────────────────────────────────────
        val btnRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER
        }

        val allowBtn = Button(this).apply {
            text    = "✅  Allow Call"
            setBackgroundColor(Color.parseColor("#10B981"))
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(32, 0, 32, 0)
            setOnClickListener {
                countDownTimer?.cancel()
                SentinelCallScreeningService.pendingService?.allowCall()
                finish()
            }
        }

        val blockBtn = Button(this).apply {
            text    = "🚫  Block Call"
            setBackgroundColor(Color.parseColor("#EF4444"))
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(32, 0, 32, 0)
            setOnClickListener {
                countDownTimer?.cancel()
                SentinelCallScreeningService.pendingService?.blockCall()
                finish()
            }
        }

        val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            setMargins(8, 0, 8, 0)
        }
        btnRow.addView(allowBtn, lp)
        btnRow.addView(blockBtn, lp)

        // ── Assemble ──────────────────────────────────────────────────────
        root.addView(icon)
        root.addView(title)
        root.addView(callerTv)
        root.addView(scoreTv)
        root.addView(reasonCard)
        root.addView(countdownTv)
        root.addView(progressBar)
        root.addView(btnRow)

        setContentView(root)

        // ── Start countdown ───────────────────────────────────────────────
        countDownTimer = object : CountDownTimer(COUNTDOWN_MS, 100) {
            override fun onTick(millisLeft: Long) {
                val secs = (millisLeft / 1000) + 1
                countdownTv.text = "Auto-blocking in ${secs}s..."
                progressBar.progress = ((millisLeft.toFloat() / COUNTDOWN_MS) * 100).toInt()
            }
            override fun onFinish() {
                countdownTv.text = "Blocking..."
                SentinelCallScreeningService.pendingService?.blockCall()
                finish()
            }
        }.start()
    }

    override fun onDestroy() {
        countDownTimer?.cancel()
        super.onDestroy()
    }
}
