package com.lumifx.lumifx

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var phoneAudio: PhoneAudioCapture? = null
    private var background: BackgroundPlaybackChannel? = null
    private var nfc: NfcChannel? = null
    private var notificationLights: NotificationLightsChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        phoneAudio = PhoneAudioCapture(this, flutterEngine.dartExecutor.binaryMessenger)
        background = BackgroundPlaybackChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        nfc = NfcChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        notificationLights =
            NotificationLightsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        // The home-screen widget's content: stored, then every widget redrawn.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lumifx/widgets")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val content = (call.arguments as? Map<*, *>)?.let { JSONObject(it) }
                    if (content != null) {
                        WidgetData.save(applicationContext, content)
                        FavoritesWidgetProvider.updateAll(applicationContext)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (phoneAudio?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        phoneAudio?.dispose()
        phoneAudio = null
        background?.dispose()
        background = null
        nfc?.dispose()
        nfc = null
        notificationLights?.dispose()
        notificationLights = null
        super.onDestroy()
    }
}
