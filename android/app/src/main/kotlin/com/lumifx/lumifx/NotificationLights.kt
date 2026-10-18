package com.lumifx.lumifx

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

/**
 * What the notification listener needs, handed over by the Dart side:
 * the bridge (host, id, pinned certificate, key), the lights and each
 * app's colour. Kept encrypted with a key from the Android keystore, as
 * it holds the bridge key.
 */
object NotificationLightsStore {
    private const val PREFS = "notification_lights"
    private const val CONFIG = "config"
    private const val ALIAS = "lumifx_notification_lights"

    @Volatile private var cache: JSONObject? = null
    @Volatile private var loaded = false

    fun save(context: Context, json: String?) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (json == null) {
            prefs.edit().remove(CONFIG).apply()
            cache = null
            loaded = true
            return
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(json.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(CONFIG, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
        cache = JSONObject(json)
        loaded = true
    }

    fun load(context: Context): JSONObject? {
        if (loaded) return cache
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(CONFIG, null)
        cache = stored?.let {
            try {
                val sealed = Base64.decode(it, Base64.NO_WRAP)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, 12))
                JSONObject(String(cipher.doFinal(sealed, 12, sealed.size - 12), Charsets.UTF_8))
            } catch (e: Exception) {
                // A key lost with a restore: the app sends it again.
                null
            }
        }
        loaded = true
        return cache
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
}

/**
 * Flashes the lights through the bridge's CLIP v2 API: `on_off_color`
 * signalling in the app's colour (just `on_off` for white lights), or a
 * breathe where the light knows no signalling. Trusts only the bridge's
 * pinned certificate, as the app does (BridgeCertificatePin in Dart).
 */
object BridgeSignal {
    private const val DURATION_MS = 3000

    fun flash(config: JSONObject, x: Double, y: Double): Boolean {
        val host = config.getString("host")
        val key = config.getString("key")
        val context = pinnedContext(
            config.getString("fingerprint").lowercase(),
            config.optString("bridgeId").lowercase(),
        )
        val lights = config.getJSONArray("lights")
        var any = false
        for (i in 0 until lights.length()) {
            val light = lights.getJSONObject(i)
            val id = light.getString("id")
            val signal = JSONObject().put(
                "signaling",
                JSONObject().apply {
                    put("duration", DURATION_MS)
                    if (light.optBoolean("color")) {
                        put("signal", "on_off_color")
                        put(
                            "colors",
                            org.json.JSONArray().put(
                                JSONObject().put("xy", JSONObject().put("x", x).put("y", y)),
                            ),
                        )
                    } else {
                        put("signal", "on_off")
                    }
                },
            )
            val ok = put(context, host, key, id, signal.toString()) ||
                put(context, host, key, id, """{"alert":{"action":"breathe"}}""")
            any = any || ok
        }
        return any
    }

    private fun pinnedContext(fingerprint: String, bridgeId: String): SSLContext {
        val trust = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {
                throw CertificateException("Not a server")
            }

            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                val leaf = chain.firstOrNull() ?: throw CertificateException("No certificate")
                if (bridgeId.isNotEmpty() &&
                    !leaf.subjectX500Principal.name.lowercase().contains("cn=$bridgeId")
                ) {
                    throw CertificateException("Another device")
                }
                val digest = MessageDigest.getInstance("SHA-256").digest(leaf.encoded)
                    .joinToString("") { "%02x".format(it) }
                if (digest != fingerprint) throw CertificateException("Another certificate")
            }

            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        }
        return SSLContext.getInstance("TLS").apply { init(null, arrayOf(trust), null) }
    }

    private fun put(context: SSLContext, host: String, key: String, id: String, body: String): Boolean {
        var connection: HttpsURLConnection? = null
        return try {
            connection = (URL("https", host, 443, "/clip/v2/resource/light/$id")
                .openConnection() as HttpsURLConnection).apply {
                sslSocketFactory = context.socketFactory
                hostnameVerifier = HostnameVerifier { name, _ -> name.equals(host, ignoreCase = true) }
                instanceFollowRedirects = false
                connectTimeout = 4000
                readTimeout = 4000
                requestMethod = "PUT"
                doOutput = true
                setRequestProperty("hue-application-key", key)
                setRequestProperty("Content-Type", "application/json")
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            connection.responseCode in 200..299
        } catch (e: Exception) {
            false
        } finally {
            connection?.disconnect()
        }
    }
}

/**
 * `com.lumifx/notification_lights`: notification access, the apps to
 * choose from, the service's settings and a test flash.
 */
class NotificationLightsChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.lumifx/notification_lights").also {
        it.setMethodCallHandler(this)
    }
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity.applicationContext
        when (call.method) {
            "hasAccess" -> result.success(
                NotificationManagerCompat.getEnabledListenerPackages(context)
                    .contains(context.packageName),
            )
            "openAccessSettings" -> {
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        ComponentName(context, NotificationLightsService::class.java).flattenToString(),
                    )
                } else {
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                }
                try {
                    activity.startActivity(intent)
                } catch (e: Exception) {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                }
                result.success(null)
            }
            "apps" -> worker.execute {
                val manager = context.packageManager
                val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                val apps = manager.queryIntentActivities(launcher, 0)
                    .map { it.activityInfo.applicationInfo }
                    .filter { it.packageName != context.packageName }
                    .distinctBy { it.packageName }
                    .map { mapOf("package" to it.packageName, "label" to manager.getApplicationLabel(it).toString()) }
                    .sortedBy { it["label"]?.lowercase() }
                main.post { result.success(apps) }
            }
            "configure" -> {
                try {
                    NotificationLightsStore.save(context, call.arguments as? String)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("store", e.message, null)
                }
            }
            "test" -> {
                val x = call.argument<Double>("x") ?: 0.3
                val y = call.argument<Double>("y") ?: 0.3
                val config = NotificationLightsStore.load(context)
                if (config == null) {
                    result.success(false)
                    return
                }
                worker.execute {
                    val ok = BridgeSignal.flash(config, x, y)
                    main.post { result.success(ok) }
                }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
