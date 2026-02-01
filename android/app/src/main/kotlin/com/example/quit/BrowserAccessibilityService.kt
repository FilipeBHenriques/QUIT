package com.example.quit

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class BrowserAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "BrowserAccessibility"
        const val ACTION_URL_VISITED = "com.example.quit.URL_VISITED"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            val packageName = event.packageName?.toString() ?: return
            
            // Focus on common browsers
            if (isBrowser(packageName)) {
                val rootNode = rootInActiveWindow ?: return
                val url = findUrlInNodes(rootNode, packageName)
                
                if (url != null) {
                    val domain = getDomain(url)
                    Log.d(TAG, "🌐 URL Detected: $url (Domain: $domain) in $packageName")
                    notifyMonitoringService(domain, packageName)
                }
                rootNode.recycle()
            }
        }
    }

    private fun isBrowser(packageName: String): Boolean {
        return packageName == "com.android.chrome" ||
               packageName == "org.mozilla.firefox" ||
               packageName == "com.opera.browser" ||
               packageName == "com.microsoft.emmx" || // Edge
               packageName == "com.duckduckgo.mobile.android" ||
               packageName == "com.brave.browser" ||
               packageName == "com.android.browser" // Generic/Samsung
    }

    private fun findUrlInNodes(node: AccessibilityNodeInfo, packageName: String): String? {
        // Known resource IDs for specific browsers
        val resourceIds = when (packageName) {
            "com.android.chrome" -> listOf("com.android.chrome:id/url_bar", "com.android.chrome:id/location_bar_view")
            "org.mozilla.firefox" -> listOf("org.mozilla.firefox:id/url_bar_title")
            else -> emptyList()
        }

        for (id in resourceIds) {
            val nodes = node.findAccessibilityNodeInfosByViewId(id)
            if (nodes.isNotEmpty()) {
                val urlNode = nodes[0]
                
                // CRITICAL: If the URL bar is focused, the user is likely typing. 
                // Skip detection to avoid premature blocks due to autocomplete.
                if (urlNode.isFocused) {
                    urlNode.recycle()
                    continue
                }
                
                val text = urlNode.text?.toString()
                urlNode.recycle()
                if (!text.isNullOrBlank() && (text.contains(".") || text.contains("://"))) {
                    return text
                }
            }
        }

        // Generic fallback: traverse and look for edit texts that look like URLs
        return dfsFindUrl(node)
    }

    private fun dfsFindUrl(node: AccessibilityNodeInfo): String? {
        if (node.className == "android.widget.EditText" || node.className == "android.view.View") {
            // Ignore if focused (typing)
            if (node.isFocused) return null
            
            val text = node.text?.toString()
            if (!text.isNullOrBlank() && isValidUrl(text)) {
                return text
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = dfsFindUrl(child)
            child.recycle()
            if (result != null) return result
        }
        return null
    }

    private fun isValidUrl(text: String): Boolean {
        // Basic heuristic for URL detection
        val clean = text.lowercase().trim()
        return (clean.startsWith("http") || clean.contains(".")) && 
               !clean.contains(" ") && 
               clean.length > 3
    }

    private fun getDomain(url: String): String {
        var domain = url.lowercase().trim()
        if (domain.startsWith("http://")) domain = domain.substring(7)
        if (domain.startsWith("https://")) domain = domain.substring(8)
        if (domain.startsWith("www.")) domain = domain.substring(4)
        
        val slashIndex = domain.indexOf("/")
        if (slashIndex != -1) {
            domain = domain.substring(0, slashIndex)
        }
        return domain
    }

    private fun notifyMonitoringService(domain: String, browserPackage: String) {
        val intent = Intent(this, MonitoringService::class.java).apply {
            action = ACTION_URL_VISITED
            putExtra("domain", domain)
            putExtra("browser_package", browserPackage)
        }
        startService(intent)
    }

    override fun onInterrupt() {}
}
