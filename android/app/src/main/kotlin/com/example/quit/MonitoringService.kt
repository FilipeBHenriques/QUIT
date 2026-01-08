package com.example.quit

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.*
import kotlin.concurrent.timer

class MonitoringService : Service() {

    private var monitoringTimer: Timer? = null
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
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        startMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringArrayListExtra("blocked_apps")?.let {
            cachedBlockedApps.clear()
            cachedBlockedApps.addAll(it)
            Log.d(TAG, "📝 Updated blocked apps: $cachedBlockedApps")
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        monitoringTimer?.cancel()
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
        // Don't block our own app
        if (foregroundApp == packageName) {
            currentlyBlockedApp = null
            return
        }

        val isBlocked = cachedBlockedApps.contains(foregroundApp)
        val isDifferentApp = foregroundApp != currentlyBlockedApp

        if (isBlocked && isDifferentApp) {
            Log.d(TAG, "🚫 Blocking app: $foregroundApp")
            val intent = Intent(this, BlockingActivity::class.java).apply {
                putExtra("packageName", foregroundApp)
                putExtra("appName", getAppLabel(foregroundApp))
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            startActivity(intent)
            currentlyBlockedApp = foregroundApp
        } else if (!isBlocked && currentlyBlockedApp != null) {
            Log.d(TAG, "✅ App no longer blocked")
            currentlyBlockedApp = null
        }
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun getCurrentForegroundApp(): String? {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val startTime = currentTime - 10000
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
            mostRecentApp ?: lastKnownForegroundApp
        } catch (e: Exception) {
            Log.e(TAG, "Error getting foreground app", e)
            lastKnownForegroundApp
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
        val pendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("QUIT - App Blocker Active")
            .setContentText("Monitoring ${cachedBlockedApps.size} blocked apps")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        monitoringTimer?.cancel()
        currentlyBlockedApp = null
        super.onDestroy()
    }
}