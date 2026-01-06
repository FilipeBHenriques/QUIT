package com.example.quit

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    private val OVERLAY_CHANNEL = "com.quit.app/overlay"
    private val PERMISSION_CHANNEL = "com.quit.app/permission"

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
    }

    private fun showOverlay(appName: String, packageName: String?) {
    if (!checkOverlayPermission()) return

    val intent = Intent(this, OverlayService::class.java).apply {
        putExtra("action", "show")
        putExtra("packageName", packageName)
        putExtra("appName", appName)
    }
    startService(intent) // no foreground service needed
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