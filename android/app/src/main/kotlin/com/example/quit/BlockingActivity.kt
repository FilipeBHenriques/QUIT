package com.example.quit

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BlockingActivity : FlutterActivity() {

    private val NAVIGATION_CHANNEL = "com.quit.app/navigation"
    private val BLOCKED_APP_CHANNEL = "com.quit.app/blocked_app"
    private val MONITORING_CHANNEL = "com.quit.app/monitoring"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make it fullscreen and prevent escape
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        hideSystemUI()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel to provide blocked app info
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKED_APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBlockedAppInfo" -> {
                    val info = mapOf(
                        "packageName" to intent.getStringExtra("packageName"),
                        "appName" to intent.getStringExtra("appName")
                    )
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }

        // Navigation channel to handle going home
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "goHome" -> {
                    goToHomeScreen()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Monitoring channel to update blocked apps
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateBlockedApps" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    updateBlockedApps(blockedApps)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateBlockedApps(blockedApps: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
            putExtra("action", "update")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun goToHomeScreen() {
        // Launch the home screen (launcher)
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        
        // Finish this blocking activity
        finish()
    }

    private fun hideSystemUI() {
        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                )
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    override fun onBackPressed() {
        // Disable back button - user cannot escape
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Disable all keys including home button (as much as possible)
        return when (keyCode) {
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_MENU -> true
            else -> super.onKeyDown(keyCode, event)
        }
    }

    override fun getInitialRoute(): String {
        return "/blocked"
    }
}