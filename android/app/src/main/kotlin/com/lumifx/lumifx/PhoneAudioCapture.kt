package com.lumifx.lumifx

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Music Sync from the audio this phone is playing (Android 10+), for the
 * Dart `PhoneAudioInput`.
 *
 * Method channel `com.lumifx/phone_audio`:
 *  - `isSupported` -> Boolean
 *  - `requestConsent` -> Boolean: shows Android's capture consent dialog
 *    and answers true when the user allowed it (the consent is kept for
 *    the next `start`, and can be used once)
 *  - `start`: starts [PhoneAudioCaptureService] with that consent
 *  - `stop`: stops it
 *
 * Event channel `com.lumifx/phone_audio/pcm`: 16-bit mono PCM chunks at
 * 44.1 kHz while the service captures; the stream ends when capture
 * stops on its own (an error, or the user ending it from the system).
 */
class PhoneAudioCapture(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    PhoneAudioCaptureService.Listener {

    private val methods = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }
    private val events = EventChannel(messenger, "$CHANNEL/pcm").also {
        it.setStreamHandler(this)
    }
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var pendingConsent: MethodChannel.Result? = null
    private var consentCode = Activity.RESULT_CANCELED
    private var consentData: Intent? = null

    init {
        PhoneAudioCaptureService.listener = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(supported)
            "requestConsent" -> requestConsent(result)
            "start" -> start(result)
            "stop" -> {
                PhoneAudioCaptureService.stop(activity)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestConsent(result: MethodChannel.Result) {
        if (!supported) {
            result.success(false)
            return
        }
        if (pendingConsent != null) {
            result.error("busy", "A consent request is already showing", null)
            return
        }
        val manager = activity.getSystemService(MediaProjectionManager::class.java)
        pendingConsent = result
        try {
            activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CONSENT)
        } catch (e: Exception) {
            pendingConsent = null
            result.error("failed", e.message, null)
        }
    }

    private fun start(result: MethodChannel.Result) {
        val data = consentData
        if (!supported || data == null) {
            result.error("no_consent", "Ask for consent before starting", null)
            return
        }
        // Android hands out each consent for one capture only.
        consentData = null
        try {
            PhoneAudioCaptureService.start(activity, consentCode, data)
            result.success(null)
        } catch (e: Exception) {
            result.error("failed", e.message, null)
        }
    }

    /** True when the result was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CONSENT) {
            return false
        }
        val result = pendingConsent ?: return true
        pendingConsent = null
        val granted = resultCode == Activity.RESULT_OK && data != null
        consentCode = resultCode
        consentData = if (granted) data else null
        result.success(granted)
        return true
    }

    // --- EventChannel.StreamHandler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // --- PhoneAudioCaptureService.Listener (any thread) ---

    override fun onPcm(bytes: ByteArray) {
        main.post { sink?.success(bytes) }
    }

    override fun onStopped(error: String?) {
        main.post {
            val s = sink ?: return@post
            if (error == null) s.endOfStream() else s.error("stopped", error, null)
            sink = null
        }
    }

    fun dispose() {
        if (PhoneAudioCaptureService.listener === this) {
            PhoneAudioCaptureService.listener = null
        }
        PhoneAudioCaptureService.stop(activity)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        pendingConsent?.error("cancelled", "The activity went away", null)
        pendingConsent = null
    }

    companion object {
        const val CHANNEL = "com.lumifx/phone_audio"
        private const val REQUEST_CONSENT = 0x4C46 // "LF"
        private val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }
}
