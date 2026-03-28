package com.example.quit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ServiceWatchdogReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ServiceWatchdog"
        const val ACTION_WATCHDOG = "com.example.quit.WATCHDOG"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🐕 Triggered: ${intent.action}")
        restartService(context)
    }

    private fun restartService(context: Context) {
        try {
            val intent = Intent(context, MonitoringService::class.java).apply {
                putExtra("action", "watchdog_restart")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "♻️ Service restart requested")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restart service: ${e.message}")
        }
    }
}
