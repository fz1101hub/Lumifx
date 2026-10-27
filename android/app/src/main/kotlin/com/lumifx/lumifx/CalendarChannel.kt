package com.lumifx.lumifx

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `com.lumifx/calendar`: the phone's appointments, read only, for the
 * lights before an appointment. `requestAccess` asks for READ_CALENDAR;
 * `events` lists the instances starting between `from` and `to`
 * (milliseconds) with their title, start and whether they last all day.
 * Only the times reach the bridge, as its own schedules.
 */
class CalendarChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.lumifx/calendar").also {
        it.setMethodCallHandler(this)
    }

    /** The `requestAccess` call waiting for the user's answer. */
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> result.success(granted())
            "requestAccess" -> {
                if (granted()) {
                    result.success(true)
                    return
                }
                pending?.success(false)
                pending = result
                activity.requestPermissions(
                    arrayOf(Manifest.permission.READ_CALENDAR), REQUEST)
            }
            "events" -> {
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (from == null || to == null || !granted()) {
                    result.success(emptyList<Any>())
                    return
                }
                result.success(events(from, to))
            }
            else -> result.notImplemented()
        }
    }

    private fun granted() =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    /** The answer to [REQUEST]; false for any other request. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST) {
            return false
        }
        pending?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pending = null
        return true
    }

    private fun events(from: Long, to: Long): List<Map<String, Any>> {
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.ALL_DAY,
        )
        val found = mutableListOf<Map<String, Any>>()
        try {
            activity.contentResolver.query(
                uri, projection, null, null,
                "${CalendarContract.Instances.BEGIN} ASC",
            )?.use { cursor ->
                while (cursor.moveToNext() && found.size < MAX_EVENTS) {
                    found.add(mapOf(
                        "title" to (cursor.getString(0) ?: ""),
                        "start" to cursor.getLong(1),
                        "allDay" to (cursor.getInt(2) == 1),
                    ))
                }
            }
        } catch (e: SecurityException) {
            // Access taken back meanwhile: no appointments.
        }
        return found
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.success(false)
        pending = null
    }

    companion object {
        private const val REQUEST = 4207
        private const val MAX_EVENTS = 50
    }
}
