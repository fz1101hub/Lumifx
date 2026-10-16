package com.lumifx.lumifx

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps LumiFX driving the lights while the screen is off: a foreground
 * service (the "connected device" kind, since the app talks to the Hue
 * Bridge over the network, plus "microphone" during Music Sync) that holds
 * a partial wake lock and a Wi-Fi lock, and shows a notification with a
 * Stop button. The effect itself still runs in the app; this only keeps
 * Android from suspending it.
 */
class PlaybackService : Service() {
    interface Listener {
        /** The notification's Stop was pressed. */
        fun onStopRequested()
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                val listener = listener
                if (listener != null) {
                    listener.onStopRequested()
                } else {
                    // The app is gone: nothing is driving the lights.
                    stopSelf()
                }
            }
            ACTION_SHOW -> show(
                intent.getStringExtra(EXTRA_TITLE) ?: "LumiFX",
                intent.getStringExtra(EXTRA_TEXT) ?: "",
                intent.getStringExtra(EXTRA_STOP) ?: "Stop",
                intent.getBooleanExtra(EXTRA_MICROPHONE, false),
            )
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    /** Shows or updates the notification and holds the locks. */
    fun show(title: String, text: String, stopLabel: String, wantsMicrophone: Boolean) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.playback_channel),
                NotificationManager.IMPORTANCE_LOW,
            )
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, PlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .addAction(0, stopLabel, stop)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        val microphone = wantsMicrophone &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                if (microphone) {
                    type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                startForeground(NOTIFICATION_ID, notification, type)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Already in the foreground and updated from the background
            // (a playlist moving on with the screen off): Android may refuse
            // a new type then, so just refresh the notification.
            manager.notify(NOTIFICATION_ID, notification)
        }
        holdLocks()
    }

    @Suppress("DEPRECATION")
    private fun holdLocks() {
        if (wakeLock == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LumiFX:playback")
                .apply {
                    setReferenceCounted(false)
                    acquire(MAX_HOLD_MS)
                }
        }
        if (wifiLock == null) {
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = applicationContext.getSystemService(WifiManager::class.java)
                .createWifiLock(mode, "LumiFX:playback")
                .apply {
                    setReferenceCounted(false)
                    acquire()
                }
        }
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        /** Set by the activity's channel. */
        @Volatile var listener: Listener? = null

        /** The running service, updated in place instead of restarted. */
        @SuppressLint("StaticFieldLeak")
        private var instance: PlaybackService? = null

        private const val CHANNEL_ID = "playback"
        private const val NOTIFICATION_ID = 0x4C47
        private const val ACTION_SHOW = "com.lumifx.lumifx.PLAYBACK_SHOW"
        private const val ACTION_STOP = "com.lumifx.lumifx.PLAYBACK_STOP"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_STOP = "stop"
        private const val EXTRA_MICROPHONE = "microphone"

        /** The wake lock lets go by itself after this, as a safety net. */
        private const val MAX_HOLD_MS = 12L * 60 * 60 * 1000

        fun show(
            context: Context,
            title: String,
            text: String,
            stopLabel: String,
            microphone: Boolean,
        ) {
            // Restarting a foreground service from the background is not
            // allowed on Android 12+, updating the running one is.
            val running = instance
            if (running != null) {
                running.show(title, text, stopLabel, microphone)
                return
            }
            val intent = Intent(context, PlaybackService::class.java)
                .setAction(ACTION_SHOW)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_STOP, stopLabel)
                .putExtra(EXTRA_MICROPHONE, microphone)
            ContextCompat.startForegroundService(context, intent)
        }

        fun hide(context: Context) {
            context.stopService(Intent(context, PlaybackService::class.java))
        }
    }
}
