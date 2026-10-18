package com.lumifx.lumifx

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.Calendar
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Flashes the lights when an app the user chose posts a notification.
 * Only the posting app's package name is looked at, never the
 * notification's title or text; nothing is stored or sent anywhere but
 * the flash to the user's own bridge.
 */
class NotificationLightsService : NotificationListenerService() {
    private var worker: ExecutorService? = null

    /** When each app last flashed the lights: a burst of messages flashes once. */
    private val lastFlash = mutableMapOf<String, Long>()

    override fun onListenerConnected() {
        worker = Executors.newSingleThreadExecutor()
    }

    override fun onListenerDisconnected() {
        worker?.shutdown()
        worker = null
    }

    override fun onNotificationPosted(notification: StatusBarNotification) {
        val app = notification.packageName
        if (app == packageName || notification.isOngoing ||
            notification.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
        ) {
            return
        }
        val config = NotificationLightsStore.load(this) ?: return
        val color = config.optJSONObject("rules")?.optJSONObject(app) ?: return
        config.optJSONObject("quiet")?.let { quiet ->
            if (inQuietHours(quiet.optInt("from"), quiet.optInt("to"))) return
        }
        val now = System.currentTimeMillis()
        if (now - (lastFlash[app] ?: 0L) < QUIET_AFTER_MS) return
        lastFlash[app] = now
        val x = color.optDouble("x", 0.3)
        val y = color.optDouble("y", 0.3)
        (worker ?: Executors.newSingleThreadExecutor().also { worker = it }).execute {
            BridgeSignal.flash(config, x, y)
        }
    }

    /** Whether now falls between [from] and [to], minutes into the day. */
    private fun inQuietHours(from: Int, to: Int): Boolean {
        val calendar = Calendar.getInstance()
        val now = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        return if (from <= to) now in from until to else now >= from || now < to
    }

    companion object {
        private const val QUIET_AFTER_MS = 15_000L
    }
}
