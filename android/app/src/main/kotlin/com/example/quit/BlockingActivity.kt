package com.example.quit

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.net.Uri
import android.widget.Toast

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
                        "appName" to intent.getStringExtra("appName"),
                        "timeLimit" to intent.getBooleanExtra("timeLimit", false),
                        "dailyLimitSeconds" to intent.getIntExtra("dailyLimitSeconds", 0),
                        "remainingSeconds" to intent.getIntExtra("remainingSeconds", 0),
                        "bonusCooldown" to intent.getBooleanExtra("bonusCooldown", false),
                        "timeUntilBonusMs" to intent.getLongExtra("timeUntilBonusMs", 0L).toInt(),
                        "totalBlock" to intent.getBooleanExtra("totalBlock", false)
                    )
                    Log.d("BlockingActivity", "📦 Sending info to Flutter: $info")
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }

        // Navigation channel to handle going home
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
    .setMethodCallHandler { call, result ->
    when (call.method) {
        "goHome" -> {
            goToHomeScreen()
            result.success(true)
        }
        "launchApp" -> {
            val packageName = call.argument<String>("packageName")
            if (packageName != null) {
                launchApp(packageName)
                result.success(true)
            } else {
                result.error("INVALID_PACKAGE", "Package name is null", null)
            }
        }
        "navigateToRoute" -> {
            val route = call.argument<String>("route")
            val blockedApp = call.argument<String>("blockedApp")
            if (route != null) {
                navigateToRoute(route, blockedApp)
                result.success(true)
            } else {
                result.error("INVALID_ROUTE", "Route is null", null)
            }
        }
        "launchUrl" -> {
            val url = call.argument<String>("url")
            if (url != null) {
                launchUrl(url)
                result.success(true)
            } else {
                result.error("INVALID_URL", "URL is null", null)
            }
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
                "updateBlockedWebsites" -> {
                    val blockedWebsites = call.argument<List<String>>("blockedWebsites") ?: emptyList()
                    updateBlockedWebsites(blockedWebsites)
                    result.success(true)
                }
                "updateTimerConfig" -> {
                    val dailyLimitSeconds = call.argument<Int>("dailyLimitSeconds") ?: 0
                    updateTimerConfig(dailyLimitSeconds)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun navigateToRoute(route: String, blockedApp: String?) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", route)
                if (blockedApp != null) {
                    putExtra("blockedApp", blockedApp)
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
            finish()
        } catch (e: Exception) {
            Log.e("BlockingActivity", "Error navigating to route: $route", e)
            goToHomeScreen()
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

    private fun updateBlockedWebsites(blockedWebsites: List<String>) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_websites", ArrayList(blockedWebsites))
            putExtra("action", "update_websites")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
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
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun launchApp(packageName: String) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                finish() // Close blocking activity
                Log.d("BlockingActivity", "🚀 Launching app: $packageName")
            } else {
                Log.e("BlockingActivity", "No launch intent for: $packageName")
                Toast.makeText(this, "Could not launch $packageName", Toast.LENGTH_SHORT).show()
                goToHomeScreen() // Fallback
            }
        } catch (e: Exception) {
            Log.e("BlockingActivity", "Error launching app: $packageName", e)
            Toast.makeText(this, "Error launching app", Toast.LENGTH_SHORT).show()
            goToHomeScreen() // Fallback
        }
    }

    private fun launchUrl(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            finish()
        } catch (e: Exception) {
            Log.e("BlockingActivity", "Error launching URL: $url", e)
            goToHomeScreen()
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
        // Determine which screen to show based on the screenType extra
        val screenType = intent.getStringExtra("screenType")
        return when (screenType) {
            "first_time_gamble" -> "/first_time_gamble"
            else -> "/blocked"
        }
    }
}