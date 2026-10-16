package com.lumifx.lumifx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.IntentCompat

/**
 * Captures the audio other apps play on this phone (Android's playback
 * capture, 10+) as 16-bit mono PCM at 44.1 kHz and hands the chunks to
 * [listener]. A foreground service, as Android requires for media
 * projection; it shows a notification while it runs and stops when the
 * app stops it, when the projection ends, or on any error.
 *
 * Only the sound is analysed; nothing is recorded, saved or sent. Apps
 * that opt out of capture (some streaming services) are simply silent
 * here.
 */
class PhoneAudioCaptureService : Service() {
    interface Listener {
        fun onPcm(bytes: ByteArray)

        /** Capture ended; [error] is null when it was asked to stop. */
        fun onStopped(error: String?)
    }

    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var reader: Thread? = null
    @Volatile private var stopping = false
    private var error: String? = null

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // Ended from the system (the status bar chip, a reboot...).
            stopWith(if (stopping) null else "projection stopped")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action != ACTION_START) {
            stopWith(null)
            return START_NOT_STICKY
        }
        if (record != null) {
            return START_NOT_STICKY
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            stopWith("unsupported")
            return START_NOT_STICKY
        }
        startInForeground()
        val code = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data = IntentCompat.getParcelableExtra(intent, EXTRA_RESULT_DATA, Intent::class.java)
        if (data == null) {
            stopWith("no consent")
            return START_NOT_STICKY
        }
        try {
            startCapture(code, data)
        } catch (e: Exception) {
            stopWith(e.message ?: e.javaClass.simpleName)
        }
        return START_NOT_STICKY
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.phone_audio_channel),
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
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.phone_audio_notification_title))
            .setContentText(getString(R.string.phone_audio_notification_text))
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(getString(R.string.phone_audio_notification_text))
            )
            .setContentIntent(open)
            .setOngoing(true)
            .setSilent(true)
            .build()
        startForeground(
            NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
        )
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun startCapture(code: Int, data: Intent) {
        val manager = getSystemService(MediaProjectionManager::class.java)
        val projection = manager.getMediaProjection(code, data)
            ?: throw IllegalStateException("no projection")
        this.projection = projection
        // Android 14 insists on a callback before any capture starts.
        projection.registerCallback(projectionCallback, Handler(Looper.getMainLooper()))

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        val record = AudioRecord.Builder()
            .setAudioFormat(format)
            .setAudioPlaybackCaptureConfig(config)
            .setBufferSizeInBytes(maxOf(minBuffer * 2, CHUNK_BYTES * 4))
            .build()
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("AudioRecord not initialised")
        }
        this.record = record
        record.startRecording()
        reader = Thread({ readLoop(record) }, "lumifx-phone-audio").also { it.start() }
    }

    private fun readLoop(record: AudioRecord) {
        val buffer = ByteArray(CHUNK_BYTES)
        while (!stopping) {
            val n = record.read(buffer, 0, buffer.size)
            if (n > 0) {
                listener?.onPcm(buffer.copyOf(n))
            } else if (n < 0) {
                Handler(Looper.getMainLooper()).post { stopWith("read error $n") }
                return
            }
        }
    }

    private fun stopWith(error: String?) {
        if (this.error == null) {
            this.error = error
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopping = true
        reader?.join(500)
        reader = null
        record?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        record = null
        projection?.let {
            it.unregisterCallback(projectionCallback)
            it.stop()
        }
        projection = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        listener?.onStopped(error)
        super.onDestroy()
    }

    companion object {
        /** Set by the activity; called from the capture thread. */
        @Volatile var listener: Listener? = null

        const val SAMPLE_RATE = 44100
        private const val CHUNK_BYTES = 4096
        private const val CHANNEL_ID = "phone_audio"
        private const val NOTIFICATION_ID = 0x4C46
        private const val ACTION_START = "com.lumifx.lumifx.PHONE_AUDIO_START"
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_RESULT_DATA = "resultData"

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, PhoneAudioCaptureService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_RESULT_CODE, resultCode)
                .putExtra(EXTRA_RESULT_DATA, data)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, PhoneAudioCaptureService::class.java))
        }
    }
}
