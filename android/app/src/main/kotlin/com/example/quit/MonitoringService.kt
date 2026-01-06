package com.example.quit

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.OnLifecycleEvent
import androidx.lifecycle.ProcessLifecycleOwner
import java.util.*
import kotlin.concurrent.timer

class MonitoringService : Service() {

    private var monitoringTimer: Timer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var cachedBlockedApps: MutableList<String> = mutableListOf()
    private var currentlyBlockedApp: String? = null
    private var lastKnownForegroundApp: String? = null

    companion object {
        private const val TAG = "MonitoringService"
        private const val NOTIFICATION_ID = 100
        private const val CHANNEL_ID = "monitoring_channel"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🟢 MonitoringService onCreate()")

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "QUIT::MonitoringWakeLock"
        )
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        // Observe when our own app comes to foreground
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : LifecycleObserver {
            @OnLifecycleEvent(Lifecycle.Event.ON_START)
            fun onEnterForeground() {
                Log.d(TAG, "📱 QUIT app entered foreground, hiding overlay")
                if (currentlyBlockedApp != null) hideBlockOverlay()
                currentlyBlockedApp = null
            }
        })

        startMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Update blocked apps list if provided
        intent?.getStringArrayListExtra("blocked_apps")?.let { newBlocked ->
            cachedBlockedApps.clear()
            cachedBlockedApps.addAll(newBlocked)
            Log.d(TAG, "🔄 Updated blocked apps list: $cachedBlockedApps")
        }

        return START_STICKY
    }

    private fun startMonitoring() {
        monitoringTimer?.cancel()
        Log.d(TAG, "🚀 Starting monitoring timer (500ms interval)")

        monitoringTimer = timer(period = 500) {
            try {
                val foregroundApp = getCurrentForegroundApp()
                if (foregroundApp != null && foregroundApp != lastKnownForegroundApp) {
                    lastKnownForegroundApp = foregroundApp
                    handler.post { handleForegroundApp(foregroundApp) }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Monitoring error", e)
            }
        }
    }

    private fun handleForegroundApp(foregroundApp: String) {
        if (foregroundApp != packageName && cachedBlockedApps.contains(foregroundApp)) {
            if (currentlyBlockedApp != foregroundApp) {
                Log.d(TAG, "🚫 BLOCKED APP DETECTED OR REOPENED: $foregroundApp")
                showBlockOverlay(foregroundApp)
                currentlyBlockedApp = foregroundApp
            }
        } else if (currentlyBlockedApp != null) {
            Log.d(TAG, "✅ Different app in foreground: $foregroundApp, hiding overlay")
            hideBlockOverlay()
            currentlyBlockedApp = null
        }
    }

    private fun getCurrentForegroundApp(): String? {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val startTime = currentTime - 10000 // look back 10 seconds
            val usageEvents = usageStatsManager.queryEvents(startTime, currentTime)
            val event = UsageEvents.Event()
            var mostRecentApp: String? = null
            var mostRecentTime = 0L

            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
                ) {
                    if (event.timeStamp > mostRecentTime) {
                        mostRecentTime = event.timeStamp
                        mostRecentApp = event.packageName
                    }
                }
            }

            // Fallback using ActivityManager for cases when UsageStatsManager misses
            if (mostRecentApp == null) {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val runningApp = am.runningAppProcesses
                    ?.firstOrNull { it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND }
                mostRecentApp = runningApp?.processName
            }

            mostRecentApp ?: lastKnownForegroundApp
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting foreground app", e)
            lastKnownForegroundApp
        }
    }

    private fun showBlockOverlay(packageName: String) {
        try {
            Log.d(TAG, "📱 Showing overlay for: $packageName")
            val intent = Intent(this, OverlayService::class.java).apply {
                putExtra("action", "show")
                putExtra("packageName", packageName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting OverlayService", e)
        }
    }

    private fun hideBlockOverlay() {
        try {
            Log.d(TAG, "🔓 Hiding overlay")
            val intent = Intent(this, OverlayService::class.java).apply {
                putExtra("action", "hide")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error hiding overlay", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors blocked apps in background"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("QUIT - App Blocker Active")
            .setContentText("Monitoring ${cachedBlockedApps.size} blocked apps")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 Service onDestroy()")
        monitoringTimer?.cancel()
        wakeLock?.release()
        hideBlockOverlay()
    }
}
