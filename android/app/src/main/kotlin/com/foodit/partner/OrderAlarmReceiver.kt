package com.foodit.partner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * BroadcastReceiver for handling Accept/Reject action button taps
 * from the alarm notification.
 *
 * Stores the action + order_id in SharedPreferences so Flutter can
 * read it on resume and trigger the appropriate bloc handler.
 */
class OrderAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "OrderAlarmReceiver"
        const val PREFS_NAME = "order_alarm_prefs"
        const val KEY_PENDING_ACTION = "pending_alarm_action"    // "accept" or "reject"
        const val KEY_PENDING_ORDER_ID = "pending_alarm_order_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val orderId = intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_ID) ?: ""
        val action = intent.action

        Log.d(TAG, "Received action: $action for order: $orderId")

        // Determine the action type
        val actionType = when (action) {
            OrderAlarmService.ACTION_ACCEPT -> "accept"
            OrderAlarmService.ACTION_REJECT -> "reject"
            "com.foodit.partner.START_ALARM" -> {
                Log.d(TAG, "Starting alarm service from background broadcast")
                val startIntent = Intent(context, OrderAlarmService::class.java).apply {
                    putExtra(OrderAlarmService.EXTRA_ORDER_ID, orderId)
                    val title = intent.getStringExtra("title") ?: "New Order!"
                    val body = intent.getStringExtra("body") ?: "You have a new order waiting"
                    putExtra(OrderAlarmService.EXTRA_TITLE, title)
                    putExtra(OrderAlarmService.EXTRA_BODY, body)
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(startIntent)
                } else {
                    context.startService(startIntent)
                }
                return
            }
            else -> {
                Log.w(TAG, "Unknown action: $action")
                return
            }
        }

        // Store in SharedPreferences for Flutter to pick up on resume
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_PENDING_ACTION, actionType)
            .putString(KEY_PENDING_ORDER_ID, orderId)
            .apply()

        Log.d(TAG, "Stored pending action: $actionType for order: $orderId")

        // Stop the alarm service
        val stopIntent = Intent(context, OrderAlarmService::class.java).apply {
            this.action = OrderAlarmService.ACTION_STOP_ALARM
        }
        context.startService(stopIntent)

        // Close the OrderAlarmActivity if it's open
        val closeActivityIntent = Intent(OrderAlarmActivity.ACTION_FINISH_ALARM_ACTIVITY)
        context.sendBroadcast(closeActivityIntent)

        Log.d(TAG, "Alarm service stop requested, alarm activity close broadcast sent")
    }
}
