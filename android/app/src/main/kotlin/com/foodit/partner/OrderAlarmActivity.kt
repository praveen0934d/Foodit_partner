package com.foodit.partner

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen activity shown over the lock screen when a new order arrives.
 * Displays Accept/Reject buttons like an incoming call UI.
 *
 * This is the target of setFullScreenIntent() — shown when the phone is locked
 * or the notification cannot be displayed in the tray.
 */
class OrderAlarmActivity : Activity() {

    companion object {
        const val TAG = "OrderAlarmActivity"
        const val ACTION_FINISH_ALARM_ACTIVITY = "com.foodit.partner.FINISH_ALARM_ACTIVITY"
    }

    private val finishReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "Received finish broadcast")
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Register broadcast receiver to close this activity
        val filter = IntentFilter(ACTION_FINISH_ALARM_ACTIVITY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(finishReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(finishReceiver, filter)
        }

        // Get order details from intent
        val orderId = intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_ID) ?: ""
        val title = intent.getStringExtra(OrderAlarmService.EXTRA_TITLE) ?: "New Order!"
        val body = intent.getStringExtra(OrderAlarmService.EXTRA_BODY) ?: "You have a new order waiting"

        // Build UI programmatically (no XML layout needed)
        val layout = buildUI(orderId, title, body)
        setContentView(layout)

        Log.d(TAG, "Full-screen alarm activity shown for order: $orderId")
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(finishReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        super.onDestroy()
    }

    // Prevent back button from dismissing
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Do nothing — force user to tap Accept or Reject
    }

    private fun buildUI(orderId: String, title: String, body: String): View {
        val dp = { value: Int -> (value * resources.displayMetrics.density).toInt() }

        // Root container — dark gradient background
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF1A1A2E.toInt())
            setPadding(dp(32), dp(64), dp(32), dp(48))
        }

        // Pulsing alarm icon (just an emoji for simplicity)
        val iconText = TextView(this).apply {
            text = "🔔"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        root.addView(iconText)

        // Spacer
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(24)
            )
        })

        // Title
        val titleText = TextView(this).apply {
            text = title
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        root.addView(titleText)

        // Spacer
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(12)
            )
        })

        // Body
        val bodyText = TextView(this).apply {
            text = body
            textSize = 16f
            setTextColor(0xAAFFFFFF.toInt())
            gravity = Gravity.CENTER
        }
        root.addView(bodyText)

        // Order ID
        if (orderId.isNotEmpty()) {
            root.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, dp(8)
                )
            })
            val orderIdText = TextView(this).apply {
                text = "Order #$orderId"
                textSize = 14f
                setTextColor(0x88FFFFFF.toInt())
                gravity = Gravity.CENTER
            }
            root.addView(orderIdText)
        }

        // Large spacer before buttons
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(64)
            )
        })

        // Button container
        val buttonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        // Reject button
        val rejectBtn = Button(this).apply {
            text = "❌  Reject"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0xFFEF4444.toInt())
            setPadding(dp(32), dp(16), dp(32), dp(16))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins(0, 0, dp(8), 0)
            }
            setOnClickListener {
                handleAction(OrderAlarmService.ACTION_REJECT, orderId)
            }
        }
        buttonContainer.addView(rejectBtn)

        // Accept button
        val acceptBtn = Button(this).apply {
            text = "✅  Accept"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0xFF22C55E.toInt())
            setPadding(dp(32), dp(16), dp(32), dp(16))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins(dp(8), 0, 0, 0)
            }
            setOnClickListener {
                handleAction(OrderAlarmService.ACTION_ACCEPT, orderId)
            }
        }
        buttonContainer.addView(acceptBtn)

        root.addView(buttonContainer)

        return root
    }

    private fun handleAction(action: String, orderId: String) {
        Log.d(TAG, "User tapped action: $action for order: $orderId")

        // Send to the receiver which handles storing + stopping service
        val intent = Intent(this, OrderAlarmReceiver::class.java).apply {
            this.action = action
            putExtra(OrderAlarmService.EXTRA_ORDER_ID, orderId)
        }
        sendBroadcast(intent)

        finish()
    }
}
