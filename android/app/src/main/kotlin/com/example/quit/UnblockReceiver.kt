package com.example.quit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UnblockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.quit.app.UNBLOCK") {
            val packageName = intent.getStringExtra("packageName")
            // Stop the overlay service
            val serviceIntent = Intent(context, OverlayService::class.java).apply {
                putExtra("action", "hide")
            }
            context.stopService(serviceIntent)
        }
    }
}

