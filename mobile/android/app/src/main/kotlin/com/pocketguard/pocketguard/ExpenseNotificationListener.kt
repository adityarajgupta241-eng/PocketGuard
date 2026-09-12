package com.pocketguard.pocketguard

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

class ExpenseNotificationListener : NotificationListenerService() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val host = prefs.getString("flutter.server_ip", "")?.trim().orEmpty()
        if (host.isEmpty()) return

        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val payload = JSONObject()
            .put("package_name", sbn.packageName)
            .put("title", title)
            .put("text", text)
            .put("timestamp", iso.format(Date(sbn.postTime)))

        worker.execute {
            postNotification(host, payload.toString())
        }
    }

    private fun postNotification(host: String, body: String) {
        val url = URL("http://$host:8000/api/notifications")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 4000
            readTimeout = 4000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }
        try {
            OutputStreamWriter(connection.outputStream).use { it.write(body) }
            connection.responseCode
        } catch (_: Exception) {
            // Local LAN drops are expected when the Mac is unreachable.
        } finally {
            connection.disconnect()
        }
    }
}
