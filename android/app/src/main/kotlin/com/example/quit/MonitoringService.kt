package com.example.quit

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.*
import androidx.core.app.NotificationCompat
import java.util.*
import kotlin.concurrent.timer
import kotlin.math.max
import android.util.Log
import android.content.SharedPreferences

class MonitoringService : Service() {

    private var monitoringTimer: Timer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var cachedBlockedApps: MutableList<String> = mutableListOf()
    private var currentlyBlockedApp: String? = null
    private var lastKnownForegroundApp: String? = null

    // Daily limit vars
    private var dailyLimitSeconds: Int = 0
    private var remainingSeconds: Int = 0
    private var sessionStartTime: Long? = null
    private var lastSaveTime: Long = 0
    private val SAVE_INTERVAL_MS = 5000L // Save every 5 seconds
    
    // Screen state tracking
    private var isScreenOn: Boolean = true
    private var screenStateReceiver: BroadcastReceiver? = null

    companion object {
        private const val TAG = "MonitoringService"
        private const val NOTIFICATION_ID = 100
        private const val CHANNEL_ID = "monitoring_channel"
        
        // Helper to safely read int values from SharedPreferences (handles both Int and Long)
        private fun SharedPreferences.getIntSafe(key: String, defaultValue: Int): Int {
            return try {
                getInt(key, defaultValue)
            } catch (e: ClassCastException) {
                // Value stored as Long, convert to Int
                getLong(key, defaultValue.toLong()).toInt()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        loadTimerState()
        checkAndResetTimer()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        registerScreenStateReceiver()
        startMonitoring()
    }
    
    private fun registerScreenStateReceiver() {
        screenStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        Log.d(TAG, "📴 Screen turned OFF - pausing time tracking")
                        isScreenOn = false
                        
                        // Save current session and stop tracking
                        stopTimeTracking()
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        Log.d(TAG, "📱 Screen turned ON - will check app after unlock completes")
                        isScreenOn = true
                        
                        // Don't check immediately - let the user unlock first
                        // We'll rely on the normal monitoring loop to detect when they
                        // actually get past the lock screen to the app
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        // This fires AFTER user unlocks (PIN/pattern/fingerprint/swipe)
                        Log.d(TAG, "🔓 User unlocked - checking current app")
                        
                        // Wait a bit for unlock animation to complete
                        handler.postDelayed({
                            val currentApp = getCurrentForegroundApp()
                            if (currentApp != null && currentApp != packageName) {
                                Log.d(TAG, "🔍 After unlock, app is: $currentApp")
                                // Force re-evaluation even if "same" app
                                lastKnownForegroundApp = null
                                handleForegroundApp(currentApp)
                            }
                        }, 1000) // 1 second delay for animation
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenStateReceiver, filter)
        
        // Check initial screen state
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        isScreenOn = powerManager.isInteractive
        Log.d(TAG, "📱 Initial screen state: ${if (isScreenOn) "ON" else "OFF"}")
    }

    private fun loadTimerState() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Use safe getter that handles both Int and Long storage
        dailyLimitSeconds = prefs.getIntSafe("flutter.daily_limit_seconds", 0)
        remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
    }

    private fun checkAndResetTimer() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastReset = prefs.getLong("flutter.timer_last_reset", 0)
        
        // Get reset interval from preferences (in seconds)
        val resetIntervalSeconds = prefs.getIntSafe("flutter.reset_interval_seconds", 86400) // Default 24h
        val resetIntervalMs = resetIntervalSeconds * 1000L

        if (lastReset > 0) {
            val timeSinceReset = System.currentTimeMillis() - lastReset
            if (timeSinceReset >= resetIntervalMs) {
                resetTimer()
            }
        }
    }

    private fun resetTimer() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        remainingSeconds = dailyLimitSeconds
        prefs.edit()
            .putInt("flutter.remaining_seconds", remainingSeconds)
            .putInt("flutter.used_today_seconds", 0)  // Reset used time
            .remove("flutter.timer_last_reset")  // Clear timestamp - wait for next usage
            .apply()
        Log.d(TAG, "⏰ Timer reset: ${remainingSeconds}s available, countdown cleared")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        
        when (action) {
            "update_timer" -> {
                // Timer config updated - reload from preferences
                val newLimit = intent.getIntExtra("daily_limit_seconds", 0)
                Log.d(TAG, "⏱️ Timer config update received: $newLimit seconds")
                loadTimerState()
                updateNotification()
            }
            else -> {
                // Normal blocked apps update
                intent?.getStringArrayListExtra("blocked_apps")?.let {
                    cachedBlockedApps.clear()
                    cachedBlockedApps.addAll(it)
                    Log.d(TAG, "📝 Updated blocked apps: $cachedBlockedApps")
                }
            }
        }
        
        return START_STICKY
    }

    private fun startMonitoring() {
        monitoringTimer?.cancel()
        monitoringTimer = timer(period = 500) {
            try {
                // Check for foreground app changes
                val foregroundApp = getCurrentForegroundApp()
                if (foregroundApp != null && foregroundApp != lastKnownForegroundApp) {
                    lastKnownForegroundApp = foregroundApp
                    handler.post { handleForegroundApp(foregroundApp) }
                }
                
                // Continuously update time tracking if active
                handler.post { updateTimeTracking() }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Monitoring error", e)
            }
        }
    }

    private fun handleForegroundApp(foregroundApp: String) {
        // Don't block our own app
        if (foregroundApp == packageName) {
            stopTimeTracking()
            currentlyBlockedApp = null
            return
        }

        val isBlocked = cachedBlockedApps.contains(foregroundApp)
        val isDifferentApp = foregroundApp != currentlyBlockedApp

        if (isBlocked) {
            // THREE CASES:
            
            // Case 1: No timer configured - traditional blocking
            if (dailyLimitSeconds == 0) {
                if (isDifferentApp) {
                    stopTimeTracking()
                    Log.d(TAG, "🚫 Blocking app (no timer): $foregroundApp")
                    showBlockingScreen(foregroundApp, timeLimit = false)
                    currentlyBlockedApp = foregroundApp
                }
            }
            // Case 2: Timer enabled but time exhausted - block with timer message
            else if (remainingSeconds <= 0) {
                if (isDifferentApp) {
                    stopTimeTracking()
                    Log.d(TAG, "⏱️ Time limit exceeded: $foregroundApp")
                    showTimeLimitExceededScreen(foregroundApp)
                    currentlyBlockedApp = foregroundApp
                }
            }
            // Case 3: Timer enabled with time remaining - ALLOW ACCESS + track time
            else {
                if (isDifferentApp) {
                    stopTimeTracking() // Stop any previous tracking
                    currentlyBlockedApp = foregroundApp
                    Log.d(TAG, "✅ Allowing access with timer: $foregroundApp (${remainingSeconds}s remaining)")
                }
                startTimeTracking() // Track time for this session
            }
        } else {
            // Not a blocked app - stop tracking
            stopTimeTracking()
            currentlyBlockedApp = null
        }
    }

    // Helper method for traditional blocking (no timer)
    private fun showBlockingScreen(foregroundApp: String, timeLimit: Boolean) {
        val intent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", foregroundApp)
            putExtra("appName", getAppLabel(foregroundApp))
            putExtra("timeLimit", timeLimit)
            putExtra("dailyLimitSeconds", dailyLimitSeconds)
            putExtra("remainingSeconds", remainingSeconds)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
    }

    private fun showTimeLimitExceededScreen(foregroundApp: String) {
        Log.d(TAG, "⏱️ Time limit exceeded for: $foregroundApp")
        val intent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", foregroundApp)
            putExtra("appName", getAppLabel(foregroundApp))
            putExtra("timeLimit", true)
            putExtra("dailyLimitSeconds", dailyLimitSeconds)
            putExtra("remainingSeconds", remainingSeconds)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
    }

    private fun startTimeTracking() {
        // Don't start tracking if screen is off
        if (!isScreenOn) {
            Log.d(TAG, "⏸️ Screen is OFF - not starting time tracking")
            return
        }
        
        if (sessionStartTime == null) {
            sessionStartTime = System.currentTimeMillis()
            lastSaveTime = System.currentTimeMillis()
            
            // IMPORTANT: Start the reset timer on first usage (if not already started)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lastReset = prefs.getLong("flutter.timer_last_reset", 0)
            if (lastReset == 0L) {
                prefs.edit()
                    .putLong("flutter.timer_last_reset", System.currentTimeMillis())
                    .apply()
                Log.d(TAG, "⏰ Started reset countdown (first app usage detected)")
            }
            
            Log.d(TAG, "⏱️ Started time tracking. Remaining: ${remainingSeconds}s")
        }
    }

    private fun stopTimeTracking() {
        sessionStartTime?.let { startTime ->
            val elapsed = ((System.currentTimeMillis() - startTime) / 1000).toInt()
            remainingSeconds = max(0, remainingSeconds - elapsed)
            
            // IMPORTANT: Increment used_today_seconds (persistent counter)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currentUsed = prefs.getIntSafe("flutter.used_today_seconds", 0)
            prefs.edit()
                .putInt("flutter.used_today_seconds", currentUsed + elapsed)
                .apply()
            
            saveTimeState()
            Log.d(TAG, "⏱️ Stopped tracking. Used: ${elapsed}s, Total used today: ${currentUsed + elapsed}s, Remaining: ${remainingSeconds}s")
        }
        sessionStartTime = null
    }

    private fun updateTimeTracking() {
        sessionStartTime?.let { startTime ->
            val currentTime = System.currentTimeMillis()
            
            // CRITICAL: Don't count time when screen is off
            if (!isScreenOn) {
                return
            }
            
            // CRITICAL: Check if reset should happen BEFORE updating counters
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lastReset = prefs.getLong("flutter.timer_last_reset", 0)
            if (lastReset > 0) {
                val resetIntervalSeconds = prefs.getIntSafe("flutter.reset_interval_seconds", 86400)
                val resetIntervalMs = resetIntervalSeconds * 1000L
                val timeSinceReset = currentTime - lastReset
                
                if (timeSinceReset >= resetIntervalMs) {
                    Log.d(TAG, "⏰ Reset time reached during tracking - triggering reset")
                    resetTimer()
                    loadTimerState() // Reload state after reset
                    // Stop tracking current session since we just reset
                    sessionStartTime = null
                    lastSaveTime = 0
                    return
                }
            }
            
            // Check if we should save (every 5 seconds)
            if (currentTime - lastSaveTime >= SAVE_INTERVAL_MS) {
                val elapsedSinceSave = ((currentTime - lastSaveTime) / 1000).toInt()
                remainingSeconds = max(0, remainingSeconds - elapsedSinceSave)
                
                // IMPORTANT: Increment used_today_seconds
                val currentUsed = prefs.getIntSafe("flutter.used_today_seconds", 0)
                prefs.edit()
                    .putInt("flutter.used_today_seconds", currentUsed + elapsedSinceSave)
                    .apply()
                
                saveTimeState()
                lastSaveTime = currentTime
                
                // Update notification with current remaining time
                updateNotification()
            }
            
            // Check if time ran out
            if (remainingSeconds <= 0 && currentlyBlockedApp != null) {
                stopTimeTracking()
                handler.post {
                    currentlyBlockedApp?.let { app ->
                        showTimeLimitExceededScreen(app)
                    }
                }
            }
        }
    }

    private fun updateNotification() {
        val notification = createNotification()
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun saveTimeState() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putInt("flutter.remaining_seconds", remainingSeconds)
            .apply()
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
        
        val contentText = if (dailyLimitSeconds > 0) {
            val minutes = remainingSeconds / 60
            val seconds = remainingSeconds % 60
            "Monitoring ${cachedBlockedApps.size} apps | ${minutes}:${seconds.toString().padStart(2, '0')} left"
        } else {
            "Monitoring ${cachedBlockedApps.size} blocked apps"
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("QUIT - App Blocker Active")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?) = null

    override fun onDestroy() {
        stopTimeTracking()
        monitoringTimer?.cancel()
        currentlyBlockedApp = null
        
        // Unregister screen state receiver
        screenStateReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering screen receiver", e)
            }
        }
        
        super.onDestroy()
    }
}