package com.example.quit

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var currentBlockedPackage: String? = null
    
    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    companion object {
        private const val TAG = "OverlayService"
        private const val NOTIFICATION_ID = 101
        private const val CHANNEL_ID = "overlay_channel"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val packageName = intent?.getStringExtra("packageName")

        Log.d(TAG, "OverlayService onStartCommand()")
        Log.d(TAG, "Action: $action")
        Log.d(TAG, "Package name received: $packageName")

        when (action) {
            "SHOW" -> {
                if (packageName != null) {
                    Log.d(TAG, "Calling showOverlay() for: $packageName")
                    showOverlay(packageName)
                } else {
                    Log.e(TAG, "Cannot show overlay - package name is null!")
                }
            }
            "HIDE" -> {
                Log.d(TAG, "Hiding overlay")
                hideOverlay()
                stopSelf()
            }
            else -> {
                Log.w(TAG, "Unknown action: $action")
            }
        }

        return START_NOT_STICKY
    }

    private fun showOverlay(packageName: String) {
        if (overlayView != null && currentBlockedPackage == packageName) {
            return
        }

        hideOverlay()
        currentBlockedPackage = packageName

        val appName = try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }

        overlayView = createOverlayLayout(appName, packageName)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(overlayView, params)
            
            // Start foreground with proper type for Android 14+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID, 
                    createNotification(),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, createNotification())
            }
            
            Log.d(TAG, "Overlay shown for: $appName")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing overlay: ${e.message}")
        }
    }

    private fun createOverlayLayout(appName: String, packageName: String): View {
        val context = this
        
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(60, 60, 60, 60)
            gravity = Gravity.CENTER
        }

        val iconText = TextView(context).apply {
            text = "🚫"
            textSize = 80f
            setTextColor(Color.RED)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 40)
            }
        }
        container.addView(iconText)

        val titleText = TextView(context).apply {
            text = "App Blocked!"
            textSize = 32f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 20)
            }
        }
        container.addView(titleText)

        val appNameText = TextView(context).apply {
            text = appName
            textSize = 24f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 60)
            }
        }
        container.addView(appNameText)

        val messageText = TextView(context).apply {
            text = "This app has been blocked.\nYou cannot access it right now."
            textSize = 16f
            setTextColor(Color.parseColor("#999999"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 60)
            }
        }
        container.addView(messageText)

        val unblockButton = Button(context).apply {
            text = "Unblock This App"
            textSize = 16f
            setBackgroundColor(Color.WHITE)
            setTextColor(Color.BLACK)
            setPadding(80, 40, 80, 40)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                unblockApp(packageName)
            }
        }
        container.addView(unblockButton)

        val homeButton = Button(context).apply {
            text = "Go to Home"
            textSize = 14f
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.parseColor("#AAAAAA"))
            setPadding(60, 40, 60, 40)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 20, 0, 0)
            }
            setOnClickListener {
                goToHome()
            }
        }
        container.addView(homeButton)

        return container
    }

    private fun unblockApp(packageName: String) {
        try {
            Log.d(TAG, "Unblocking app: $packageName")
            
            // Get current blocked apps
            val blockedApps = getBlockedApps().toMutableList()
            val initialSize = blockedApps.size
            
            // Remove the app
            blockedApps.remove(packageName)
            
            Log.d(TAG, "Blocked apps before: $initialSize, after: ${blockedApps.size}")
            
            // Save in BOTH formats for compatibility
            val editor = prefs.edit()
            
            // Format 1: JSON string (for Kotlin/MonitoringService)
            val jsonString = if (blockedApps.isEmpty()) {
                "[]"
            } else {
                blockedApps.joinToString(prefix = "[\"", postfix = "\"]", separator = "\",\"")
            }
            editor.putString("blocked_apps", jsonString)
            
            // Format 2: String set (backup format)
            editor.putStringSet("blocked_apps_set", blockedApps.toSet())
            
            // Commit changes
            val success = editor.commit()
            
            Log.d(TAG, "SharedPreferences save success: $success")
            Log.d(TAG, "New blocked apps JSON: $jsonString")
            
            if (success) {
                // Hide overlay immediately
                hideOverlay()
                
                // Go to home screen
                goToHome()
                
                // Stop this service
                stopSelf()
                
                Log.d(TAG, "App successfully unblocked: $packageName")
            } else {
                Log.e(TAG, "Failed to save SharedPreferences")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error unblocking app: ${e.message}", e)
        }
    }

    private fun getBlockedApps(): List<String> {
        return try {
            // Try JSON format first
            val blockedAppsJson = prefs.getString("blocked_apps", null)
            if (blockedAppsJson != null && blockedAppsJson.isNotEmpty()) {
                return parseBlockedApps(blockedAppsJson)
            }
            
            // Try string set format
            val blockedAppsSet = prefs.getStringSet("blocked_apps_set", null)
            if (blockedAppsSet != null) {
                return blockedAppsSet.toList()
            }
            
            emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting blocked apps: ${e.message}")
            emptyList()
        }
    }

    private fun goToHome() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            hideOverlay()
        } catch (e: Exception) {
            Log.e(TAG, "Error going home: ${e.message}")
        }
    }

    private fun parseBlockedApps(json: String): List<String> {
        return try {
            json.trim('[', ']')
                .split(',')
                .map { it.trim().trim('"') }
                .filter { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing blocked apps: ${e.message}")
            emptyList()
        }
    }

    private fun hideOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
                Log.d(TAG, "Overlay hidden")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay: ${e.message}")
            }
            overlayView = null
            currentBlockedPackage = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocking Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows blocking overlay"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("QUIT - Blocking App")
            .setContentText("App blocker is active")
            .setSmallIcon(android.R.drawable.ic_delete)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
    }
}