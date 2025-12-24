package com.example.quit

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val OVERLAY_CHANNEL = "com.quit.app/overlay"
    private val PERMISSION_CHANNEL = "com.quit.app/permission"
    private val SERVICE_CHANNEL = "com.quit.app/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverlay" -> {
                        val packageName = call.argument<String>("packageName")
                        showOverlay(packageName)
                        result.success(true)
                    }
                    "hideOverlay" -> {
                        hideOverlay()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL)
            .setMethodCallHandler { call, result ->
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
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoringService" -> {
                        // Get blocked apps list from Dart
                        val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                        startMonitoringService(blockedApps)
                        result.success(true)
                    }
                    "stopMonitoringService" -> {
                        stopMonitoringService()
                        result.success(true)
                    }
                    "updateBlockedApps" -> {
                        // Update the service with new blocked apps list
                        val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                        updateBlockedApps(blockedApps)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startMonitoringService(blockedApps: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun updateBlockedApps(blockedApps: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
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

    private fun showOverlay(packageName: String?) {
        if (!checkOverlayPermission()) {
            println("Overlay permission not granted")
            return
        }

        val intent = Intent(this, OverlayService::class.java).apply {
            action = "SHOW"
            putExtra("packageName", packageName)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = "HIDE"
        }
        startService(intent)
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