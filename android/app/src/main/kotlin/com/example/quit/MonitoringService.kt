package com.example.quit

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.*
import kotlin.concurrent.timer

class MonitoringService : Service() {
    private var monitoringTimer: Timer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var cachedBlockedApps: List<String> = emptyList()
    private var methodChannel: MethodChannel? = null
    private var flutterEngine: FlutterEngine? = null
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "MonitoringService"
        private const val NOTIFICATION_ID = 100
        private const val CHANNEL_ID = "monitoring_channel"
        private const val METHOD_CHANNEL = "com.quit.app/blocked_apps"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate()")
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "QUIT::MonitoringWakeLock"
        )
        wakeLock?.acquire(10*60*1000L)
        
        createNotificationChannel()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, 
                createNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        
        // Setup Flutter engine for communication
        setupFlutterEngine()
        
        startMonitoring()
    }
    
    private fun setupFlutterEngine() {
        try {
            // Use existing Flutter engine or create new one
            flutterEngine = FlutterEngine(applicationContext)
            
            handler.post {
                methodChannel = MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    METHOD_CHANNEL
                )
                
                Log.d(TAG, "MethodChannel created for communication with Flutter")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up Flutter engine", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand()")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, 
                createNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        
        // Refresh blocked apps list when service is called
        intent?.getStringArrayListExtra("blocked_apps")?.let { apps ->
            cachedBlockedApps = apps
            Log.d(TAG, "Received blocked apps from intent: $cachedBlockedApps")
        }
        
        if (monitoringTimer == null) {
            startMonitoring()
        }
        
        return START_STICKY
    }

    private fun startMonitoring() {
        monitoringTimer?.cancel()
        
        Log.d(TAG, "Starting monitoring timer")
        Log.d(TAG, "Initial cached blocked apps: $cachedBlockedApps")
        
        monitoringTimer = timer(period = 1000) {
            try {
                val foregroundApp = getCurrentForegroundApp()
                if (foregroundApp != null && foregroundApp != packageName) {
                    checkAndBlockApp(foregroundApp)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Monitoring error", e)
            }
        }
        
        Log.d(TAG, "Monitoring started successfully")
    }

    private fun getCurrentForegroundApp(): String? {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val startTime = currentTime - 5000

            val usageEvents = usageStatsManager.queryEvents(startTime, currentTime)
            var lastEvent: UsageEvents.Event? = null

            while (usageEvents.hasNextEvent()) {
                val event = UsageEvents.Event()
                usageEvents.getNextEvent(event)
                
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastEvent = event
                }
            }

            return lastEvent?.packageName
        } catch (e: Exception) {
            Log.e(TAG, "Error getting foreground app", e)
            return null
        }
    }

    private fun checkAndBlockApp(packageName: String) {
        try {
            // Use cached list
            if (cachedBlockedApps.contains(packageName)) {
                Log.d(TAG, "🚫 BLOCKED APP DETECTED: $packageName")
                Log.d(TAG, "Showing overlay for: $packageName")
                showBlockOverlay(packageName)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking blocked app", e)
        }
    }

    private fun showBlockOverlay(packageName: String) {
        try {
            val intent = Intent(this, OverlayService::class.java).apply {
                action = "SHOW"
                putExtra("packageName", packageName)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Starting OverlayService as foreground service")
                startForegroundService(intent)
            } else {
                Log.d(TAG, "Starting OverlayService")
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting OverlayService", e)
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
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service onDestroy()")
        monitoringTimer?.cancel()
        wakeLock?.release()
        flutterEngine?.destroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed - restarting service")
        
        val restartServiceIntent = Intent(applicationContext, MonitoringService::class.java).apply {
            putStringArrayListExtra("blocked_apps", ArrayList(cachedBlockedApps))
        }
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(
            AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
    }
}