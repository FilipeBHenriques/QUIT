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
import android.net.Uri

class MonitoringService : Service() {

    private var monitoringTimer: Timer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentlyBlockedApp: String? = null
    private var lastKnownForegroundApp: String? = null

    // Time tracking state
    private var sessionStartTime: Long? = null
    private var lastSaveTime: Long = 0
    private val SAVE_INTERVAL_MS = 1000L // Save every 1 second for better accuracy
    
    // Screen state tracking
    private var isScreenOn: Boolean = true
    private var screenStateReceiver: BroadcastReceiver? = null

    companion object {
        private const val TAG = "MonitoringService"
        private const val NOTIFICATION_ID = 100
        private const val CHANNEL_ID = "monitoring_channel"
        
        // Static caches to survive service re-creation
        private var cachedBlockedApps: MutableList<String> = mutableListOf()
        private var cachedBlockedWebsites: MutableList<String> = mutableListOf()
        
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
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        checkAndPerformReset(prefs) // Single reset check at startup
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

    // SINGLE SOURCE OF TRUTH: Check and perform reset if needed
    private fun checkAndPerformReset(prefs: SharedPreferences) {
    val dailyLimitSeconds = prefs.getIntSafe("flutter.daily_limit_seconds", 0)
    if (dailyLimitSeconds == 0) return
    
    val lastReset = prefs.getLong("flutter.timer_last_reset", 0L)
    if (lastReset == 0L) {
        prefs.edit()
            .putLong("flutter.timer_last_reset", System.currentTimeMillis())
            .apply()
        return
    }
    
    val resetIntervalSeconds = prefs.getIntSafe("flutter.reset_interval_seconds", 86400)
    val resetIntervalMs = resetIntervalSeconds * 1000L
    val timeSinceReset = System.currentTimeMillis() - lastReset
    
    if (timeSinceReset >= resetIntervalMs) {
        Log.d(TAG, "⏰ 24h timer expired - resetting now!")
        prefs.edit()
            .putInt("flutter.remaining_seconds", dailyLimitSeconds)
            .putInt("flutter.used_today_seconds", 0)
            .remove("flutter.timer_last_reset")
            .remove("flutter.daily_time_ran_out_timestamp") // Clear the ran out timestamp
            .remove("flutter.timer_first_choice_made") // Reset choice flag to show gamble screen again
            // NOTE: DON'T reset last_bonus_time ← IMPORTANT
            .apply()
    }
}

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: intent?.getStringExtra("action")
        Log.d(TAG, "onStartCommand: action=$action")
        
        when (action) {
            "update_timer" -> {
                // Timer config updated - just update notification
                val newLimit = intent?.getIntExtra("daily_limit_seconds", 0) ?: 0
                Log.d(TAG, "⏱️ Timer config update received: $newLimit seconds")
                updateNotification()
            }
            "com.example.quit.URL_VISITED" -> {
                val domain = intent?.getStringExtra("domain")
                val browserPackage = intent?.getStringExtra("browser_package")
                Log.d(TAG, "🔗 URL visit: $domain in $browserPackage")
                if (domain != null) {
                    handleWebsiteVisit(domain, browserPackage)
                }
            }
            "update_websites" -> {
                intent?.getStringArrayListExtra("blocked_websites")?.let {
                    cachedBlockedWebsites.clear()
                    cachedBlockedWebsites.addAll(it)
                    Log.d(TAG, "📝 Updated blocked websites: $cachedBlockedWebsites")
                }
            }
            else -> {
                // Normal blocked apps update or refresh request
                intent?.getStringArrayListExtra("blocked_apps")?.let {
                    cachedBlockedApps.clear()
                    cachedBlockedApps.addAll(it)
                    Log.d(TAG, "📝 Updated blocked apps: $cachedBlockedApps")
                }
                
                // Also update websites if provided
                intent?.getStringArrayListExtra("blocked_websites")?.let {
                    cachedBlockedWebsites.clear()
                    cachedBlockedWebsites.addAll(it)
                    Log.d(TAG, "📝 Updated blocked websites: $cachedBlockedWebsites")
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

    private fun showBonusCooldownScreen(
    foregroundApp: String,
    dailyLimitSeconds: Int,
    timeUntilBonusMs: Long
) {
    val intent = Intent(this, BlockingActivity::class.java).apply {
        putExtra("packageName", foregroundApp)
        putExtra("appName", getAppLabel(foregroundApp))
        putExtra("timeLimit", true)
        putExtra("dailyLimitSeconds", dailyLimitSeconds)
        putExtra("remainingSeconds", 0) // Daily time is exhausted
        putExtra("bonusCooldown", true)
        putExtra("timeUntilBonusMs", timeUntilBonusMs)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }
    startActivity(intent)
    Log.d(TAG, "🎰 Showing bonus cooldown screen for $foregroundApp")
}


    private fun showFirstTimeGambleScreen(foregroundApp: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val dailyLimitSeconds = prefs.getIntSafe("flutter.daily_limit_seconds", 0)
        val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)

        val intent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", foregroundApp)
            putExtra("appName", getAppLabel(foregroundApp))
            putExtra("screenType", "first_time_gamble")
            putExtra("dailyLimitSeconds", dailyLimitSeconds)
            putExtra("remainingSeconds", remainingSeconds)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
        Log.d(TAG, "🎰 Showing first time gamble screen for $foregroundApp (rem: $remainingSeconds)")
    }

    private fun handleWebsiteVisit(domain: String, browserPackage: String?) {
        val isBlocked = cachedBlockedWebsites.any { blocked -> 
            domain == blocked || domain.endsWith(".$blocked")
        }

        if (isBlocked) {
            Log.w(TAG, "🚫 Blocked website detected: $domain")
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)

            if (true) { // Websites are always strictly blocked now
                // Pre-emptively redirect the browser to Google
                // This clears the blocked URL from the active tab automatically
                redirectToSafeUrl(browserPackage)
                
                // Add a small delay for the browser to process the redirect
                // before the blocking screen takes over
                handler.postDelayed({
                    showWebsiteBlockScreen(domain)
                }, 500)
            }
        }
    }

    private fun redirectToSafeUrl(browserPackage: String?) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                if (browserPackage != null) {
                    setPackage(browserPackage)
                }
            }
            startActivity(intent)
            Log.d(TAG, "🌐 Pre-emptively redirecting browser $browserPackage to Google")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during pre-emptive redirect", e)
        }
    }

    private fun showWebsiteBlockScreen(domain: String) {
        val intent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", "browser") // Generic identifier
            putExtra("appName", domain)
            putExtra("screenType", "website_block")
            putExtra("totalBlock", true) // No bonus/gamble for websites
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
    }

    private fun handleForegroundApp(foregroundApp: String) {
        if (foregroundApp == packageName) {
            if (currentlyBlockedApp != null) {
                stopTimeTracking()
                currentlyBlockedApp = null
                Log.d(TAG, "✅ User returned to QUIT app - stopped tracking")
            }
            return
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val dailyLimitSeconds = prefs.getIntSafe("flutter.daily_limit_seconds", 0)

        if (dailyLimitSeconds > 0 && cachedBlockedApps.contains(foregroundApp)) {
            val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
            val dailyRanOutTimestamp = prefs.getLong("flutter.daily_time_ran_out_timestamp", 0L)
            val hasNmadeChoice = prefs.getBoolean("flutter.timer_first_choice_made", false)
            
            Log.d(TAG, "🎯 Blocked app detected: $foregroundApp (remaining: ${remainingSeconds}s, dailyRanOut: $dailyRanOutTimestamp, madeChoice: $hasNmadeChoice)")

            // Check if user hasn't made their first choice yet (e.g., after reset)
            if (!hasNmadeChoice && remainingSeconds > 0) {
                // Show gamble screen for first-time choice after reset
                Log.d(TAG, "🎰 First time after reset - showing gamble screen")
                showFirstTimeGambleScreen(foregroundApp)
            } else if (remainingSeconds > 0) {
                // Daily time still available - allow usage and track time
                currentlyBlockedApp = foregroundApp
                startTimeTracking()
            } else {
                // Daily time exhausted - check bonus system
                val lastBonusTimestamp = prefs.getLong("flutter.last_bonus_time", 0L)
                val bonusRefillIntervalSeconds = prefs.getIntSafe("flutter.bonus_refill_interval_seconds", 3600)
                val bonusRefillIntervalMs = bonusRefillIntervalSeconds * 1000L
                
                val now = System.currentTimeMillis()
                
                // If daily time just ran out, mark the timestamp
                if (dailyRanOutTimestamp == 0L) {
                    prefs.edit()
                        .putLong("flutter.daily_time_ran_out_timestamp", now)
                        .apply()
                    Log.d(TAG, "⏰ Marked daily time ran out at $now")
                }
                
                // CRITICAL: Re-read the actual stored timestamp after potentially setting it
                val actualRanOutTime = prefs.getLong("flutter.daily_time_ran_out_timestamp", now)
                
                // Check if bonus is available
                val bonusAvailable: Boolean
                val timeUntilBonusMs: Long
                
                if (lastBonusTimestamp == 0L) {
                    // Never granted bonus - check time since daily ran out
                    val timeSinceRanOut = now - actualRanOutTime
                    bonusAvailable = timeSinceRanOut >= bonusRefillIntervalMs
                    timeUntilBonusMs = if (bonusAvailable) 0L else (bonusRefillIntervalMs - timeSinceRanOut)
                    Log.d(TAG, "🎲 Never granted: timeSince=${timeSinceRanOut}ms, timeUntil=${timeUntilBonusMs}ms (${timeUntilBonusMs/1000}s)")
                } else {
                    // Previously granted - check time since last bonus
                    val timeSinceLastBonus = now - lastBonusTimestamp
                    bonusAvailable = timeSinceLastBonus >= bonusRefillIntervalMs
                    timeUntilBonusMs = if (bonusAvailable) 0L else (bonusRefillIntervalMs - timeSinceLastBonus)
                    Log.d(TAG, "🎲 Previously: timeSince=${timeSinceLastBonus}ms, timeUntil=${timeUntilBonusMs}ms (${timeUntilBonusMs/1000}s)")
                }
                
                if (bonusAvailable) {
                    // Bonus is ready! Show gamble screen so user can choose to gamble or use the time
                    // The bonus will be granted when they click "Continue to App" in the gamble screen
                    Log.d(TAG, "🎁 Bonus available! Showing gamble screen")
                    showFirstTimeGambleScreen(foregroundApp)
                } else {
                    // Show bonus cooldown screen with both timers
                    Log.d(TAG, "⏳ Bonus cooldown: ${timeUntilBonusMs}ms (${timeUntilBonusMs/1000}s) remaining")
                    showBonusCooldownScreen(foregroundApp, dailyLimitSeconds, timeUntilBonusMs)
                }
            }
        } else if (cachedBlockedApps.contains(foregroundApp)) {
            // No timer - regular block
            val intent = Intent(this, BlockingActivity::class.java).apply {
                putExtra("packageName", foregroundApp)
                putExtra("appName", getAppLabel(foregroundApp))
                putExtra("timeLimit", false)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
            Log.d(TAG, "🚫 Showing block screen for $foregroundApp")
        } else {
            // Not blocked
            if (currentlyBlockedApp != null) {
                stopTimeTracking()
                currentlyBlockedApp = null
                Log.d(TAG, "✅ Switched to non-blocked app - stopped tracking")
            }
        }
    }

    private fun startTimeTracking() {
        if (sessionStartTime == null) {
            sessionStartTime = System.currentTimeMillis()
            lastSaveTime = sessionStartTime!!
            
            // SINGLE PLACE: Set reset timestamp if not set
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lastReset = prefs.getLong("flutter.timer_last_reset", 0)
            if (lastReset == 0L) {
                prefs.edit()
                    .putLong("flutter.timer_last_reset", System.currentTimeMillis())
                    .apply()
                Log.d(TAG, "⏰ Started 24h reset countdown")
            }
            
            // Check if they've made a choice (timer_first_choice_made flag)
            val hasNmadeChoice = prefs.getBoolean("flutter.timer_first_choice_made", false)
            
            if (hasNmadeChoice) {
                // User already made their choice - timer should already be running
                val lastReset = prefs.getLong("flutter.timer_last_reset", 0)
                if (lastReset == 0L) {
                    // Shouldn't happen, but safety check
                    prefs.edit()
                        .putLong("flutter.timer_last_reset", System.currentTimeMillis())
                        .apply()
                    Log.d(TAG, "⏰ Started reset countdown (safety fallback)")
                }
            }
            
            val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
            Log.d(TAG, "⏱️ Started time tracking. Remaining: ${remainingSeconds}s")
        }
    }

    private fun stopTimeTracking() {
        sessionStartTime?.let { startTime ->
            // Use lastSaveTime to calculate elapsed since last save, NOT start time
            // This prevents double counting time that was already deducted in updateTimeTracking
            val referenceTime = if (lastSaveTime > 0) lastSaveTime else startTime
            val elapsed = ((System.currentTimeMillis() - referenceTime) / 1000).toInt()
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
            val newRemaining = max(0, remainingSeconds - elapsed)
            
            // IMPORTANT: Increment used_today_seconds (persistent counter)
            val currentUsed = prefs.getIntSafe("flutter.used_today_seconds", 0)
            val editor = prefs.edit()
                .putInt("flutter.remaining_seconds", newRemaining)
                .putInt("flutter.used_today_seconds", currentUsed + elapsed)
            
            // If remaining just hit 0, mark that daily time ran out
            if (newRemaining == 0 && remainingSeconds > 0) {
                editor.putLong("flutter.daily_time_ran_out_timestamp", System.currentTimeMillis())
                Log.d(TAG, "⏰ Daily time ran out in stopTimeTracking - marked timestamp")
            }
            
            editor.apply()
            
            Log.d(TAG, "⏱️ Stopped tracking. Used: ${elapsed}s since last save. Remaining: ${newRemaining}s")
        }
        sessionStartTime = null
        lastSaveTime = 0 // Reset last save time
    }

    private fun updateTimeTracking() {
        sessionStartTime?.let { startTime ->
            val currentTime = System.currentTimeMillis()
            
            // CRITICAL: Don't count time when screen is off
            if (!isScreenOn) {
                return
            }
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Check if we should save (every 5 seconds)
            if (currentTime - lastSaveTime >= SAVE_INTERVAL_MS) {
                val elapsedSinceSave = ((currentTime - lastSaveTime) / 1000).toInt()
                val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
                val newRemaining = max(0, remainingSeconds - elapsedSinceSave)
                
                // IMPORTANT: Increment used_today_seconds
                val currentUsed = prefs.getIntSafe("flutter.used_today_seconds", 0)
                val editor = prefs.edit()
                    .putInt("flutter.remaining_seconds", newRemaining)
                    .putInt("flutter.used_today_seconds", currentUsed + elapsedSinceSave)
                
                // If remaining just hit 0, mark that daily time ran out
                if (newRemaining == 0 && remainingSeconds > 0) {
                    editor.putLong("flutter.daily_time_ran_out_timestamp", System.currentTimeMillis())
                    Log.d(TAG, "⏰ Daily time ran out - marked timestamp")
                }
                
                editor.apply()
                
                // CRITICAL FIX: Only advance lastSaveTime by the amount we actually accounted for (integers)
                // This prevents losing fractional seconds (e.g. 1.9s -> 1s accounted, 0.9s lost if we reset to currentTime)
                lastSaveTime += (elapsedSinceSave * 1000)
                
                // Update notification with current remaining time
                updateNotification()
                
                // Check if time ran out
                // Safety: Check foreground app if currentlyBlockedApp is null to prevent bypass
                val effectiveBlockedApp = currentlyBlockedApp ?: getCurrentForegroundApp()?.takeIf { cachedBlockedApps.contains(it) }

                if (newRemaining <= 0 && effectiveBlockedApp != null) {
                    Log.d(TAG, "⏰ Time ran out for $effectiveBlockedApp (current: $currentlyBlockedApp)")
                    stopTimeTracking()
                    val app = effectiveBlockedApp 
                    currentlyBlockedApp = null // Clear to prevent re-showing
                    
                    handler.post {
                        val blockedApp = app // safe local copy
                            val dailyLimit = prefs.getIntSafe("flutter.daily_limit_seconds", 0)
                            
                            // Check bonus availability
                            val dailyRanOutTimestamp = prefs.getLong("flutter.daily_time_ran_out_timestamp", 0L)
                            val lastBonusTimestamp = prefs.getLong("flutter.last_bonus_time", 0L)
                            val bonusRefillIntervalSeconds = prefs.getIntSafe("flutter.bonus_refill_interval_seconds", 3600)
                            val bonusRefillIntervalMs = bonusRefillIntervalSeconds * 1000L
                            
                            val now = System.currentTimeMillis()
                            val bonusAvailable: Boolean
                            val timeUntilBonusMs: Long
                            
                            if (lastBonusTimestamp == 0L) {
                                // Never granted - check time since daily ran out
                                val timeSinceRanOut = now - dailyRanOutTimestamp
                                bonusAvailable = timeSinceRanOut >= bonusRefillIntervalMs
                                timeUntilBonusMs = if (bonusAvailable) 0L else (bonusRefillIntervalMs - timeSinceRanOut)
                            } else {
                                // Previously granted - check time since last bonus
                                val timeSinceLastBonus = now - lastBonusTimestamp
                                bonusAvailable = timeSinceLastBonus >= bonusRefillIntervalMs
                                timeUntilBonusMs = if (bonusAvailable) 0L else (bonusRefillIntervalMs - timeSinceLastBonus)
                            }
                            
                            if (bonusAvailable) {
                                // Bonus is ready! Show gamble screen
                                Log.d(TAG, "🎁 Bonus available after time ran out! Showing gamble screen")
                                showFirstTimeGambleScreen(blockedApp)
                            } else {
                                // Show bonus cooldown screen
                                Log.d(TAG, "⏳ Time ran out while in app! Showing cooldown screen")
                                showBonusCooldownScreen(blockedApp, dailyLimit, timeUntilBonusMs)
                            }
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
        
        // Read current values from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val dailyLimitSeconds = prefs.getIntSafe("flutter.daily_limit_seconds", 0)
        val remainingSeconds = prefs.getIntSafe("flutter.remaining_seconds", 0)
        
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