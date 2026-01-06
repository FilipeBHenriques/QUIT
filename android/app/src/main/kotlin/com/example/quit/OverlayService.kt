package com.example.quit

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    companion object {
        private const val TAG = "OverlayService"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            @Suppress("DEPRECATION")
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        val packageName = intent?.getStringExtra("packageName")
        val appName = intent?.getStringExtra("appName") ?: packageName ?: "App"

        when (action) {
            "show" -> showOverlay(appName, packageName)
            "hide" -> hideOverlay()
        }

        return START_STICKY
    }

    private fun showOverlay(appName: String, packageName: String?) {
        if (overlayView != null) return

        var displayName = appName
        if (packageName != null) {
            try {
                val pm = packageManager
                val appInfo = pm.getApplicationInfo(packageName, 0)
                displayName = pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                displayName = appName.ifEmpty { packageName }
            }
        }

        val layoutInflater = LayoutInflater.from(this)
        overlayView = layoutInflater.inflate(R.layout.overlay_blocking, null)

        val textView = overlayView?.findViewById<TextView>(R.id.blockedAppName)
        textView?.text = "$displayName is blocked!"

        // Close button (X) - just hides overlay, doesn't unblock
        val closeButton = overlayView?.findViewById<ImageButton>(R.id.closeButton)
        closeButton?.setOnClickListener {
            Log.d(TAG, "❌ Close button - hiding overlay (app stays blocked)")
            hideOverlay()
        }

        // Unblock button - permanently unblocks the app
        val unblockButton = overlayView?.findViewById<Button>(R.id.unblockButton)
        unblockButton?.setOnClickListener {
            Log.d(TAG, "🟢 UNBLOCK button - permanently unblocking $packageName")
            
            if (packageName != null) {
                unblockAppPermanently(packageName)
            }
            
            hideOverlay()
            // DON'T go home - let user stay in the app they just unblocked
        }

        // KEY FIX: NOT_TOUCHABLE + NOT_FOCUSABLE allows touches to pass through to the app below
        // This lets user swipe away the blocked app in recents
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            // NOT_TOUCH_MODAL allows touches outside the view to reach below
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ Overlay shown (touches pass through, app can be swiped away)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay", e)
        }
    }

    private fun unblockAppPermanently(packageName: String) {
        try {
            Log.d(TAG, "════════════════════════════════════════")
            Log.d(TAG, "🔓 UNBLOCKING: $packageName")
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            val blockedAppsJson = prefs.getString("flutter.blocked_apps", null)
            Log.d(TAG, "📋 Current JSON: $blockedAppsJson")
            
            val blockedApps = parseBlockedAppsFromJson(blockedAppsJson).toMutableList()
            Log.d(TAG, "📋 Parsed list BEFORE remove: $blockedApps")
            
            val removed = blockedApps.remove(packageName)
            Log.d(TAG, "🗑️ Removed $packageName? $removed")
            Log.d(TAG, "📋 List AFTER remove: $blockedApps")
            
            // Save new list
            val editor = prefs.edit()
            
            if (blockedApps.isEmpty()) {
                // If empty, remove the key entirely
                editor.remove("flutter.blocked_apps")
                Log.d(TAG, "💾 List is empty, removing key entirely")
            } else {
                val newJson = convertListToFlutterJson(blockedApps)
                Log.d(TAG, "💾 Saving new JSON: $newJson")
                editor.putString("flutter.blocked_apps", newJson)
            }
            
            val saved = editor.commit()  // COMMIT not apply!
            Log.d(TAG, "💾 Commit result: $saved")
            
            // Verify what was saved
            val verify = prefs.getString("flutter.blocked_apps", null)
            Log.d(TAG, "✅ VERIFY after save: $verify")
            
            // Update MonitoringService
            val intent = Intent(this, MonitoringService::class.java).apply {
                putStringArrayListExtra("blocked_apps", ArrayList(blockedApps))
                putExtra("action", "update")
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            
            Log.d(TAG, "✅ MonitoringService updated with: $blockedApps")
            Log.d(TAG, "════════════════════════════════════════")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ ERROR unblocking", e)
        }
    }

    private fun hideOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
                Log.d(TAG, "✅ Overlay hidden")
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding", e)
            }
            overlayView = null
        }
    }

    private fun goHome() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            Log.d(TAG, "✅ Went home")
        } catch (e: Exception) {
            Log.e(TAG, "Error going home", e)
        }
    }

    private fun parseBlockedAppsFromJson(json: String?): List<String> {
        if (json == null || json == "null") return emptyList()
        
        return try {
            var processedJson = json.trim()
            
            if (processedJson.contains("!")) {
                val indexOfBracket = processedJson.indexOf('[')
                if (indexOfBracket != -1) {
                    processedJson = processedJson.substring(indexOfBracket)
                }
            }
            
            if (processedJson == "[]") return emptyList()
            
            processedJson
                .trim('[', ']')
                .split(",")
                .map { it.trim().trim('"') }
                .filter { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e(TAG, "Parse error", e)
            emptyList()
        }
    }
    
    private fun convertListToFlutterJson(list: List<String>): String {
        val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
        val jsonArray = list.joinToString(",") { "\"$it\"" }
        return "$prefix[$jsonArray]"
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "overlay_channel",
                "Blocking Overlay",
                NotificationManager.IMPORTANCE_LOW
            )
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "overlay_channel")
            .setContentTitle("QUIT")
            .setContentText("App blocked")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .build()
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
    }
}