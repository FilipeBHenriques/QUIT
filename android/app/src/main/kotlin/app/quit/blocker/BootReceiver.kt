package app.quit.blocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.d(TAG, "📱 Device booted - checking if service should restart")

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val hasBlockedApps = prefs.getString("flutter.blocked_apps", null) != null ||
                    prefs.getStringSet("flutter.blocked_apps", null)?.isNotEmpty() == true
            val hasBlockedWebsites = prefs.getString("flutter.blocked_websites", null) != null ||
                    prefs.getStringSet("flutter.blocked_websites", null)?.isNotEmpty() == true

            if (hasBlockedApps || hasBlockedWebsites) {
                Log.d(TAG, "♻️ Restarting MonitoringService after boot")
                val serviceIntent = Intent(context, MonitoringService::class.java).apply {
                    putExtra("action", "boot_restart")
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to restart service after boot", e)
                }
            }
        }
    }
}
