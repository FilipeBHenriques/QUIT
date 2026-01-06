package com.example.quit

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    private val OVERLAY_CHANNEL = "com.quit.app/overlay"
    private val PERMISSION_CHANNEL = "com.quit.app/permission"
    private val MONITORING_CHANNEL = "com.quit.app/monitoring"
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("my_engine", flutterEngine)
        
        // Overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverlay" -> {
                    val packageName = call.argument<String>("packageName")
                    val appName = call.argument<String>("appName") ?: packageName ?: "App"
                    showOverlay(appName, packageName)
                    result.success(true)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Permission channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Monitoring service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    Log.d(TAG, "🟢 startMonitoring called with: $blockedApps")
                    startMonitoringService(blockedApps)
                    result.success(true)
                }
                "stopMonitoring" -> {
                    Log.d(TAG, "🔴 stopMonitoring called")
                    stopMonitoringService()
                    result.success(true)
                }
                "updateBlockedApps" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    Log.d(TAG, "🔄 updateBlockedApps called with: $blockedApps")
                    updateBlockedApps(blockedApps)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startMonitoringService(blockedApps: List<String>) {
        Log.d(TAG, "▶️ Starting MonitoringService with ${blockedApps.size} blocked apps")
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
            putExtra("action", "start")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG, "✅ MonitoringService start command sent")
    }

    private fun stopMonitoringService() {
        Log.d(TAG, "⏹️ Stopping MonitoringService")
        val intent = Intent(this, MonitoringService::class.java)
        stopService(intent)
    }

    private fun updateBlockedApps(blockedApps: List<String>) {
        Log.d(TAG, "════════════════════════════════════════")
        Log.d(TAG, "🔄 UPDATING BLOCKED APPS")
        Log.d(TAG, "   New list: $blockedApps")
        Log.d(TAG, "   List size: ${blockedApps.size}")
        Log.d(TAG, "════════════════════════════════════════")
        
        // Send update intent to service
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
            putExtra("action", "update")  // Add action to distinguish update from start
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
                Log.d(TAG, "✅ Sent update via startForegroundService")
            } else {
                startService(intent)
                Log.d(TAG, "✅ Sent update via startService")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating blocked apps", e)
        }
    }

    private fun showOverlay(appName: String, packageName: String?) {
        if (!checkOverlayPermission()) return

        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra("action", "show")
            putExtra("packageName", packageName)
            putExtra("appName", appName)
        }
        startService(intent)
    }

    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra("action", "hide")
        }
        stopService(intent)
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
        }
    }
}