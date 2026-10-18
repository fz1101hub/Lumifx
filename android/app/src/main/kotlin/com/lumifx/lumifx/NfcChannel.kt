package com.lumifx.lumifx

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `com.lumifx/nfc`: writes a lumifx:// link on an NFC sticker. `write`
 * waits for a sticker in reader mode and answers how it went (the names
 * of NfcWriteResult on the Dart side). Touching the sticker later opens
 * the link through the NDEF_DISCOVERED filter in the manifest.
 */
class NfcChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.lumifx/nfc").also {
        it.setMethodCallHandler(this)
    }
    private val main = Handler(Looper.getMainLooper())
    private val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)

    /** The `write` call waiting for a sticker. */
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(adapter != null)
            "isEnabled" -> result.success(adapter?.isEnabled == true)
            "openSettings" -> {
                try {
                    activity.startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                } catch (e: ActivityNotFoundException) {
                    activity.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                }
                result.success(null)
            }
            "write" -> {
                val uri = call.argument<String>("uri")
                val nfc = adapter
                if (uri == null || nfc == null || !nfc.isEnabled) {
                    result.success("unavailable")
                    return
                }
                complete("cancelled")
                pending = result
                val message = NdefMessage(arrayOf(NdefRecord.createUri(uri)))
                nfc.enableReaderMode(
                    activity,
                    { tag ->
                        val outcome = writeTag(tag, message)
                        main.post { complete(outcome) }
                    },
                    NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                        NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V,
                    null,
                )
            }
            "cancel" -> {
                complete("cancelled")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** On the reader's thread: writes [message] and says how it went. */
    private fun writeTag(tag: Tag, message: NdefMessage): String {
        try {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                try {
                    if (!ndef.isWritable) return "readOnly"
                    if (ndef.maxSize < message.toByteArray().size) return "tooSmall"
                    ndef.writeNdefMessage(message)
                    return "written"
                } finally {
                    closeQuietly { ndef.close() }
                }
            }
            val blank = NdefFormatable.get(tag)
            if (blank != null) {
                blank.connect()
                try {
                    blank.format(message)
                    return "written"
                } finally {
                    closeQuietly { blank.close() }
                }
            }
            return "notNdef"
        } catch (e: Exception) {
            // Moved away too soon, or the sticker refused.
            return "failed"
        }
    }

    /** On the main thread: answers the waiting call and stops reading. */
    private fun complete(outcome: String) {
        val result = pending ?: return
        pending = null
        try {
            adapter?.disableReaderMode(activity)
        } catch (e: Exception) {
            // The activity is already paused, which ends reader mode too.
        }
        result.success(outcome)
    }

    private inline fun closeQuietly(close: () -> Unit) {
        try {
            close()
        } catch (e: Exception) {
            // Already gone.
        }
    }

    fun dispose() {
        complete("cancelled")
        channel.setMethodCallHandler(null)
    }
}
