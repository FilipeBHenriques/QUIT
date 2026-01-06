package com.example.quit

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        
        // Start foreground service
        // For Android 14+ (API 34+), the foregroundServiceType is declared in manifest
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            // Use special use type for overlay service
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
        if (overlayView != null) {
            return // Already showing
        }

        // Get actual app name from package manager
        var displayName = appName
        if (packageName != null) {
            try {
                val pm = packageManager
                val appInfo = pm.getApplicationInfo(packageName, 0)
                displayName = pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                // Use provided name or package name
                displayName = appName.ifEmpty { packageName }
            }
        }

        val layoutInflater = LayoutInflater.from(this)
        overlayView = layoutInflater.inflate(R.layout.overlay_blocking, null)

        val textView = overlayView?.findViewById<TextView>(R.id.blockedAppName)
        textView?.text = "$displayName is blocked!"

        val unblockButton = overlayView?.findViewById<Button>(R.id.unblockButton)
        
        // Inside your OverlayService, in unblockButton click listener:
        unblockButton?.setOnClickListener {
            hideOverlay()

            // Send MethodChannel message to Flutter
            try {
                // Get cached FlutterEngine
                val flutterEngine = FlutterEngineCache.getInstance().get("my_engine")
                flutterEngine?.dartExecutor?.let { executor ->
                    val channel = MethodChannel(executor, "com.quit.app/overlay")
                    channel.invokeMethod("unblockedApp", mapOf("packageName" to packageName))
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            overlayView = null
        }
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
            .setContentTitle("QUIT App Blocker")
            .setContentText("Monitoring blocked apps")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .build()
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
    }
}

