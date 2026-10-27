package com.lumifx.lumifx

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.URL
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext

/**
 * Leaving and coming home with the app closed: a proximity alert around
 * home, and on crossing it this phone tells the bridge itself (its own
 * presence sensor; the last one out switches every light off; after dark
 * the hall lights up). The same as `leftHome`/`cameHome` in Dart.
 */
object HomeAway {
    private const val PREFS = "home_away"
    private const val CONFIG = "config"
    private const val ALIAS = "lumifx_home_away"
    private const val ACTION = "com.lumifx.lumifx.HOME_AWAY"

    fun save(context: Context, json: String?) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (json == null) {
            prefs.edit().remove(CONFIG).apply()
            return
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(json.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(CONFIG, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
    }

    fun load(context: Context): JSONObject? {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(CONFIG, null) ?: return null
        return try {
            val sealed = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, 12))
            JSONObject(String(cipher.doFinal(sealed, 12, sealed.size - 12), Charsets.UTF_8))
        } catch (e: Exception) {
            // A key lost with a restore: the app sends it again.
            null
        }
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private fun pending(context: Context): PendingIntent {
        val intent = Intent(context, HomeAwayReceiver::class.java).setAction(ACTION)
        // Mutable: the system adds whether the phone is entering.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(context, 4208, intent, flags)
    }

    fun hasLocation(context: Context) =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /** Watches the circle around home, or stops without settings. */
    @SuppressLint("MissingPermission")
    fun register(context: Context) {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val config = load(context)
        try {
            manager.removeProximityAlert(pending(context))
            if (config != null && hasLocation(context)) {
                manager.addProximityAlert(
                    config.getDouble("latitude"),
                    config.getDouble("longitude"),
                    config.getInt("radius").toFloat(),
                    -1,
                    pending(context),
                )
            }
        } catch (e: SecurityException) {
            // Location taken back: nothing to watch.
        }
    }

    /** The phone crossed the circle: tells the bridge. */
    fun cross(context: Context, entering: Boolean) {
        val config = load(context) ?: return
        val host = config.getString("host")
        val key = config.getString("key")
        val sensor = config.getString("sensor")
        val ssl = BridgeSignal.pinnedContext(
            config.getString("fingerprint").lowercase(),
            config.optString("bridgeId").lowercase(),
        )
        fun call(method: String, path: String, body: String? = null) =
            request(ssl, host, method, "/api/$key$path", body)
        call("PUT", "/sensors/$sensor/state", """{"presence":$entering}""")
        val sensors = call("GET", "/sensors")?.let {
            try { JSONObject(it) } catch (e: Exception) { null }
        } ?: return
        if (!entering) {
            if (!config.optBoolean("offOnLeave", true)) return
            val someoneHome = sensors.keys().asSequence().any { id ->
                val value = sensors.optJSONObject(id) ?: return@any false
                val counts = value.optString("type") == "Geofence" ||
                    (value.optString("type") == "CLIPPresence" &&
                        value.optString("modelid") == "LumiFXPresence")
                id != sensor && counts &&
                    value.optJSONObject("state")?.optBoolean("presence") == true
            }
            if (!someoneHome) {
                call("PUT", "/groups/0/action", """{"on":false,"transitiontime":20}""")
            }
        } else {
            val hall = if (config.isNull("hallGroup")) "" else config.optString("hallGroup")
            if (hall.isEmpty()) return
            val dark = sensors.keys().asSequence().any { id ->
                val value = sensors.optJSONObject(id)
                value?.optString("type") == "Daylight" &&
                    value.optJSONObject("state")?.let {
                        it.has("daylight") && !it.isNull("daylight") && !it.getBoolean("daylight")
                    } == true
            }
            if (dark) {
                call("PUT", "/groups/$hall/action", """{"on":true,"bri":180,"ct":366}""")
            }
        }
    }

    private fun request(
        context: SSLContext,
        host: String,
        method: String,
        path: String,
        body: String?,
    ): String? {
        var connection: HttpsURLConnection? = null
        return try {
            connection = (URL("https", host, 443, path).openConnection() as HttpsURLConnection).apply {
                sslSocketFactory = context.socketFactory
                hostnameVerifier = HostnameVerifier { name, _ -> name.equals(host, ignoreCase = true) }
                instanceFollowRedirects = false
                connectTimeout = 5000
                readTimeout = 5000
                requestMethod = method
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                }
            }
            if (body != null) {
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            if (connection.responseCode !in 200..299) return null
            connection.inputStream.bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    @SuppressLint("MissingPermission")
    fun lastLocation(context: Context): Location? {
        if (!hasLocation(context)) return null
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return try {
            manager.getProviders(true)
                .mapNotNull { manager.getLastKnownLocation(it) }
                .maxByOrNull { it.time }
        } catch (e: SecurityException) {
            null
        }
    }
}

/** The proximity alert around home (only the system's, not exported). */
class HomeAwayReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!intent.hasExtra(LocationManager.KEY_PROXIMITY_ENTERING)) return
        val entering = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false)
        val pending = goAsync()
        Executors.newSingleThreadExecutor().execute {
            try {
                HomeAway.cross(context.applicationContext, entering)
            } finally {
                pending.finish()
            }
        }
    }
}

/** After a restart the proximity alert is gone: set it again. */
class HomeAwayBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            HomeAway.register(context.applicationContext)
        }
    }
}

/**
 * `com.lumifx/home_away`: the location permission (also in the
 * background), where the phone is now, and the settings.
 */
class HomeAwayChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.lumifx/home_away").also {
        it.setMethodCallHandler(this)
    }
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestAccess" -> {
                pending?.success(false)
                pending = result
                if (!HomeAway.hasLocation(activity)) {
                    activity.requestPermissions(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                        ),
                        FOREGROUND,
                    )
                } else {
                    askBackground()
                }
            }
            "currentLocation" -> {
                val location = HomeAway.lastLocation(activity)
                result.success(
                    location?.let { mapOf("latitude" to it.latitude, "longitude" to it.longitude) },
                )
            }
            "configure" -> {
                val config = (call.arguments as? Map<*, *>)?.let { JSONObject(it).toString() }
                HomeAway.save(activity, config)
                HomeAway.register(activity)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun askBackground() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            activity.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            answer(true)
            return
        }
        activity.requestPermissions(
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), BACKGROUND)
    }

    private fun answer(granted: Boolean) {
        pending?.success(granted)
        pending = null
    }

    /** The answers to this channel's requests; false for any other. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        when (requestCode) {
            FOREGROUND -> {
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                    askBackground()
                } else {
                    answer(false)
                }
            }
            BACKGROUND -> answer(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            else -> return false
        }
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        answer(false)
    }

    companion object {
        private const val FOREGROUND = 4209
        private const val BACKGROUND = 4210
    }
}
