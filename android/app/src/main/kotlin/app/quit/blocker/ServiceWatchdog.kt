package app.quit.blocker

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ServiceWatchdog : BroadcastReceiver() {
    companion object {
        private const val TAG = "ServiceWatchdog"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "⏰ Watchdog triggered - checking service status")

        if (!isServiceRunning(context)) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val hasBlockedApps = prefs.getString("flutter.blocked_apps", null) != null ||
                    prefs.getStringSet("flutter.blocked_apps", null)?.isNotEmpty() == true
            val hasBlockedWebsites = prefs.getString("flutter.blocked_websites", null) != null ||
                    prefs.getStringSet("flutter.blocked_websites", null)?.isNotEmpty() == true

            if (hasBlockedApps || hasBlockedWebsites) {
                Log.w(TAG, "♻️ Service dead but should be running - restarting!")
                val serviceIntent = Intent(context, MonitoringService::class.java).apply {
                    putExtra("action", "watchdog_restart")
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Watchdog failed to restart service", e)
                }
            }
        } else {
            Log.d(TAG, "✅ Service is alive")
        }
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (MonitoringService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
