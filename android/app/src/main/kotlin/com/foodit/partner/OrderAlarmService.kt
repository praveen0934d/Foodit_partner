package com.foodit.partner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that plays a looping alarm on STREAM_ALARM
 * and posts a full-screen intent notification with Accept/Reject buttons.
 *
 * Triggered from Flutter via MethodChannel when a new_order FCM data
 * payload arrives (works in background and killed states).
 */
class OrderAlarmService : Service() {

    companion object {
        const val TAG = "OrderAlarmService"
        const val CHANNEL_ID = "order_alarm_channel"
        const val NOTIFICATION_ID = 9001
        const val AUTO_STOP_MS = 120_000L // 2 minutes

        const val EXTRA_ORDER_ID = "order_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        // Actions for the BroadcastReceiver
        const val ACTION_ACCEPT = "com.foodit.partner.ACTION_ACCEPT_ORDER"
        const val ACTION_REJECT = "com.foodit.partner.ACTION_REJECT_ORDER"
        const val ACTION_STOP_ALARM = "com.foodit.partner.ACTION_STOP_ALARM"

        var isRunning = false
            private set
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val autoStopRunnable = Runnable { stopSelfCleanup() }
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val orderId = intent?.getStringExtra(EXTRA_ORDER_ID) ?: ""
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "New Order!"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "You have a new order waiting"

        // If STOP action, clean up
        if (intent?.action == ACTION_STOP_ALARM) {
            stopSelfCleanup()
            return START_NOT_STICKY
        }

        Log.d(TAG, "Starting alarm for order: $orderId")
        isRunning = true

        // Acquire wake lock to keep CPU on
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "foodit:OrderAlarmWakeLock"
        ).apply {
            acquire(AUTO_STOP_MS)
        }

        // Start as foreground service with full-screen intent notification
        val notification = buildAlarmNotification(orderId, title, body)
        startForeground(NOTIFICATION_ID, notification)

        // Play alarm sound on STREAM_ALARM (bypasses DND on most devices)
        startAlarmSound()

        // Auto-stop safety net
        handler.postDelayed(autoStopRunnable, AUTO_STOP_MS)

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopSelfCleanup()
        super.onDestroy()
    }

    private fun startAlarmSound() {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                val afd = resources.openRawResourceFd(R.raw.new_order_alarm)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                setVolume(1.0f, 1.0f)
                prepare()
                start()
            }

            // Also boost alarm volume to max
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

            Log.d(TAG, "Alarm sound started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start alarm sound: ${e.message}", e)
        }
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
            mediaPlayer = null
            Log.d(TAG, "Alarm sound stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm: ${e.message}", e)
        }
    }

    private fun stopSelfCleanup() {
        Log.d(TAG, "Cleaning up and stopping service")
        isRunning = false
        handler.removeCallbacks(autoStopRunnable)
        stopAlarmSound()

        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}", e)
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Order Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm for incoming food orders"
                setBypassDnd(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildAlarmNotification(orderId: String, title: String, body: String): Notification {
        // Intent to open the app when notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full-screen intent — shows over lock screen
        val fullScreenIntent = Intent(this, OrderAlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(EXTRA_ORDER_ID, orderId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 1, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Accept button
        val acceptIntent = Intent(this, OrderAlarmReceiver::class.java).apply {
            action = ACTION_ACCEPT
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        val acceptPendingIntent = PendingIntent.getBroadcast(
            this, 2, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Reject button
        val rejectIntent = Intent(this, OrderAlarmReceiver::class.java).apply {
            action = ACTION_REJECT
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        val rejectPendingIntent = PendingIntent.getBroadcast(
            this, 3, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openAppPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, "✅ Accept", acceptPendingIntent)
            .addAction(0, "❌ Reject", rejectPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
}
