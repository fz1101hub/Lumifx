package com.lumifx.lumifx

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `com.lumifx/background`: `show` / `hide` the [PlaybackService]; calls
 * `stop` on the Dart side when the notification's Stop is pressed.
 */
class BackgroundPlaybackChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, PlaybackService.Listener {

    private val channel = MethodChannel(messenger, "com.lumifx/background").also {
        it.setMethodCallHandler(this)
    }
    private val main = Handler(Looper.getMainLooper())
    private var askedForNotifications = false

    init {
        PlaybackService.listener = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                askForNotificationsOnce()
                try {
                    PlaybackService.show(
                        activity.applicationContext,
                        call.argument<String>("title") ?: "LumiFX",
                        call.argument<String>("text") ?: "",
                        call.argument<String>("stop") ?: "Stop",
                        call.argument<Boolean>("microphone") ?: false,
                    )
                    result.success(true)
                } catch (e: Exception) {
                    // E.g. started from the background on Android 12+: the
                    // effect then stops with the screen, as before.
                    result.success(false)
                }
            }
            "hide" -> {
                PlaybackService.hide(activity.applicationContext)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Android 13+: the Stop button only shows with notification access. */
    private fun askForNotificationsOnce() {
        if (askedForNotifications || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        askedForNotifications = true
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0x4C48,
            )
        }
    }

    override fun onStopRequested() {
        main.post { channel.invokeMethod("stop", null) }
    }

    fun dispose() {
        if (PlaybackService.listener === this) {
            PlaybackService.listener = null
        }
        PlaybackService.hide(activity.applicationContext)
        channel.setMethodCallHandler(null)
    }
}
