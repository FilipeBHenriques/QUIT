package com.example.quit

import android.content.Intent
import android.os.Build
import android.util.Log
import android.provider.Settings
import android.app.AppOpsManager
import android.content.Context
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.PowerManager
import android.text.TextUtils
import android.widget.Toast

class MainActivity : FlutterActivity() {

    private val MONITORING_CHANNEL = "com.quit.app/monitoring"
    private val USAGE_ACCESS_REQUEST_CODE = 1001
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1002
    private val ACCESSIBILITY_REQUEST_CODE = 1004

    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Check and request permissions on startup
        checkAndRequestPermissions()

        // Monitoring channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    Log.d(TAG, "🟢 startMonitoring called with: $blockedApps")
                    startMonitoringService(blockedApps)
                    result.success(true)
                }
                "stopMonitoring" -> {
                    stopMonitoringService()
                    result.success(true)
                }
                "updateBlockedApps" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    updateBlockedApps(blockedApps)
                    result.success(true)
                }
                "updateBlockedWebsites" -> {
                    val blockedWebsites = call.argument<List<String>>("blockedWebsites") ?: emptyList()
                    updateBlockedWebsites(blockedWebsites)
                    result.success(true)
                }
                "updateTimerConfig" -> {
                    val dailyLimitSeconds = call.argument<Int>("dailyLimitSeconds") ?: 0
                    Log.d(TAG, "⏱️ Updating timer config: $dailyLimitSeconds seconds")
                    updateTimerConfig(dailyLimitSeconds)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkAndRequestPermissions() {
        // Check all required permissions
        val hasUsageAccess = checkUsageStatsPermission()
        val hasOverlayPermission = checkOverlayPermission()
        val hasBatteryOptimization = checkBatteryOptimization()

        Log.d(TAG, "🔍 Permission check:")
        Log.d(TAG, "   Usage Access: $hasUsageAccess")
        Log.d(TAG, "   Overlay: $hasOverlayPermission")
        Log.d(TAG, "   Battery Optimization: $hasBatteryOptimization")

        // Silently redirect to settings if permissions missing
        if (!hasUsageAccess) {
            requestUsageAccessPermission()
        } else if (!isAccessibilityServiceEnabled()) {
            requestAccessibilityPermission()
        } else if (!hasOverlayPermission) {
            requestOverlayPermission()
        } else if (!hasBatteryOptimization) {
            requestBatteryOptimization()
        }
    }

    // ============= USAGE ACCESS PERMISSION =============
    private fun checkUsageStatsPermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            Log.e(TAG, "Error checking usage stats permission", e)
            false
        }
    }

    private fun requestUsageAccessPermission() {
        try {
            Log.d(TAG, "📱 Opening Usage Access settings...")
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivityForResult(intent, USAGE_ACCESS_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening usage access settings", e)
        }
    }

    // ============= ACCESSIBILITY PERMISSION =============

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/${BrowserAccessibilityService::class.java.canonicalName}"
        val enabled = Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
        if (enabled == 1) {
            val settingValue = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            if (settingValue != null) {
                val splitter = TextUtils.SimpleStringSplitter(':')
                splitter.setString(settingValue)
                while (splitter.hasNext()) {
                    if (splitter.next().equals(service, ignoreCase = true)) return true
                }
            }
        }
        return false
    }

    private fun requestAccessibilityPermission() {
        Log.d(TAG, "♿ Accessibility permission required")
        Toast.makeText(this, "Please enable QUIT in Accessibility settings", Toast.LENGTH_LONG).show()
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivityForResult(intent, ACCESSIBILITY_REQUEST_CODE)
    }

    // ============= OVERLAY PERMISSION =============
    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Log.d(TAG, "📱 Opening Overlay permission settings...")
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
            } catch (e: Exception) {
                Log.e(TAG, "Error opening overlay settings", e)
            }
        }
    }

    // ============= BATTERY OPTIMIZATION =============
    private fun checkBatteryOptimization(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Log.d(TAG, "📱 Opening Battery Optimization settings...")
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error opening battery optimization settings", e)
            }
        }
    }

    // ============= ACTIVITY RESULT HANDLING =============
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            USAGE_ACCESS_REQUEST_CODE -> {
                if (checkUsageStatsPermission()) {
                    Log.d(TAG, "✅ Usage Access permission granted!")
                    // Check next permission
                    if (!isAccessibilityServiceEnabled()) {
                        requestAccessibilityPermission()
                    } else if (!checkOverlayPermission()) {
                        requestOverlayPermission()
                    }
                } else {
                    Log.w(TAG, "⚠️ Usage Access permission NOT granted")
                }
            }
            ACCESSIBILITY_REQUEST_CODE -> {
                if (isAccessibilityServiceEnabled()) {
                    Log.d(TAG, "✅ Accessibility permission granted!")
                    // Check next permission
                    if (!checkOverlayPermission()) {
                        requestOverlayPermission()
                    }
                } else {
                    Log.w(TAG, "⚠️ Accessibility permission NOT granted")
                }
            }
            OVERLAY_PERMISSION_REQUEST_CODE -> {
                if (checkOverlayPermission()) {
                    Log.d(TAG, "✅ Overlay permission granted!")
                    // Check next permission
                    if (!checkBatteryOptimization()) {
                        requestBatteryOptimization()
                    }
                } else {
                    Log.w(TAG, "⚠️ Overlay permission NOT granted")
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-check permissions when app resumes
        val hasUsageAccess = checkUsageStatsPermission()
        Log.d(TAG, "📱 App resumed. Usage Access: $hasUsageAccess")
    }

    // ============= SERVICE MANAGEMENT =============
    private fun startMonitoringService(blockedApps: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
            putExtra("action", "start")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, MonitoringService::class.java)
        stopService(intent)
    }

    private fun updateBlockedApps(blockedApps: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
            putExtra("action", "update")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun updateBlockedWebsites(blockedWebsites: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_websites", ArrayList(blockedWebsites))
            putExtra("action", "update_websites")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }



    private fun updateTimerConfig(dailyLimitSeconds: Int) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putExtra("action", "update_timer")
            putExtra("daily_limit_seconds", dailyLimitSeconds)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}