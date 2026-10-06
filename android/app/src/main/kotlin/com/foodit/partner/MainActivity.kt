package com.foodit.partner

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val TAG = "MainActivity"
        const val ALARM_CHANNEL = "com.foodit.partner/alarm"
        const val BATTERY_CHANNEL = "com.foodit.partner/battery"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── Alarm MethodChannel ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmService" -> {
                        val orderId = call.argument<String>("orderId") ?: ""
                        val title = call.argument<String>("title") ?: "New Order!"
                        val body = call.argument<String>("body") ?: ""
                        startAlarmService(orderId, title, body)
                        result.success(true)
                    }
                    "stopAlarmService" -> {
                        stopAlarmService()
                        result.success(true)
                    }
                    "isAlarmRunning" -> {
                        result.success(OrderAlarmService.isRunning)
                    }
                    "checkPendingAlarmAction" -> {
                        val pending = checkPendingAlarmAction()
                        result.success(pending)
                    }
                    "clearPendingAlarmAction" -> {
                        clearPendingAlarmAction()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── Battery Optimization MethodChannel ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimized" -> {
                        result.success(isBatteryOptimized())
                    }
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    "requestBatteryExemption" -> {
                        requestBatteryExemption()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        val opened = openAutoStartSettings()
                        result.success(opened)
                    }
                    "canUseFullScreenIntent" -> {
                        result.success(canUseFullScreenIntent())
                    }
                    "requestFullScreenIntent" -> {
                        requestFullScreenIntent()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Alarm Methods ───

    private fun startAlarmService(orderId: String, title: String, body: String) {
        Log.d(TAG, "Starting OrderAlarmService for order: $orderId")
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            putExtra(OrderAlarmService.EXTRA_ORDER_ID, orderId)
            putExtra(OrderAlarmService.EXTRA_TITLE, title)
            putExtra(OrderAlarmService.EXTRA_BODY, body)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAlarmService() {
        Log.d(TAG, "Stopping OrderAlarmService")
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            action = OrderAlarmService.ACTION_STOP_ALARM
        }
        startService(intent)
    }

    private fun checkPendingAlarmAction(): Map<String, String>? {
        val prefs: SharedPreferences = getSharedPreferences(
            OrderAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE
        )
        val action = prefs.getString(OrderAlarmReceiver.KEY_PENDING_ACTION, null)
        val orderId = prefs.getString(OrderAlarmReceiver.KEY_PENDING_ORDER_ID, null)

        if (action != null && orderId != null) {
            Log.d(TAG, "Found pending alarm action: $action for order: $orderId")
            return mapOf("action" to action, "order_id" to orderId)
        }
        return null
    }

    private fun clearPendingAlarmAction() {
        val prefs: SharedPreferences = getSharedPreferences(
            OrderAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE
        )
        prefs.edit().clear().apply()
        Log.d(TAG, "Cleared pending alarm action")
    }

    // ─── Battery Optimization Methods ───

    /**
     * Returns true if the app is NOT ignoring battery optimizations
     * (i.e., battery optimizations ARE applied — app is at risk of being killed).
     */
    private fun isBatteryOptimized(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return !pm.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Request AOSP battery optimization exemption via system dialog.
     */
    private fun requestBatteryExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery exemption: ${e.message}")
            // Some OEMs block this intent silently — fallback handled on Dart side
        }
    }

    /**
     * Open OEM-specific autostart / battery settings page.
     * Returns true if a specific OEM page was opened, false if fell back to App Info.
     */
    private fun openAutoStartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        Log.d(TAG, "Device manufacturer: $manufacturer")

        // OEM-specific autostart activities — each wrapped in try/catch
        // because these component names change across firmware updates
        val oemIntents: List<Intent> = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )),
                Intent().setComponent(ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.powercenter.PowerSettings"
                ))
            )
            manufacturer.contains("oppo") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                )),
                Intent().setComponent(ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity"
                ))
            )
            manufacturer.contains("vivo") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )),
                Intent().setComponent(ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
                ))
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )),
                Intent().setComponent(ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                ))
            )
            manufacturer.contains("samsung") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.battery.ui.BatteryActivity"
                )),
                Intent().setComponent(ComponentName(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.battery.ui.BatteryActivity"
                ))
            )
            manufacturer.contains("realme") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                ))
            )
            manufacturer.contains("oneplus") -> listOf(
                Intent().setComponent(ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                ))
            )
            else -> emptyList()
        }

        // Try each OEM intent, first success wins
        for (oemIntent in oemIntents) {
            try {
                oemIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(oemIntent)
                Log.d(TAG, "Opened OEM autostart settings: ${oemIntent.component}")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "OEM intent failed: ${oemIntent.component} — ${e.message}")
                // Try next one
            }
        }

        // Fallback: open App Info page
        try {
            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallbackIntent)
            Log.d(TAG, "Fell back to App Info settings")
        } catch (e: Exception) {
            Log.e(TAG, "Even App Info fallback failed: ${e.message}")
        }
        return false
    }

    // ─── Full Screen Intent Methods ───

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(NotificationManager::class.java)
            return nm.canUseFullScreenIntent()
        }
        return true
    }

    private fun requestFullScreenIntent() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request full screen intent: ${e.message}")
            }
        }
    }
}
