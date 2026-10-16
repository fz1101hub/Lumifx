package com.lumifx.lumifx

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

/**
 * The home-screen widget of the favourite effects. Its content comes from
 * the app (see [WidgetData]); a tap on a tile opens a lumifx:// link, which
 * the app plays like any other link, and a tap on the title opens the app.
 */
class FavoritesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, views(context))
        }
    }

    companion object {
        private val slots = intArrayOf(
            R.id.widget_slot0, R.id.widget_slot1, R.id.widget_slot2, R.id.widget_slot3,
        )

        /** Redraws every placed widget with the latest content. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, FavoritesWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                manager.updateAppWidget(ids, views(context))
            }
        }

        private fun views(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_favorites)
            val data = WidgetData.read(context)
            data?.optString("title")?.takeIf { it.isNotEmpty() }?.let {
                views.setTextViewText(R.id.widget_title, it)
            }
            data?.optString("empty")?.takeIf { it.isNotEmpty() }?.let {
                views.setTextViewText(R.id.widget_empty, it)
            }
            val effects = data?.optJSONArray("effects") ?: JSONArray()
            val count = minOf(effects.length(), slots.size)
            views.setViewVisibility(R.id.widget_empty, if (count == 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_row_top, if (count > 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_row_bottom, if (count > 2) View.VISIBLE else View.GONE)
            for ((index, slot) in slots.withIndex()) {
                if (index >= count) {
                    views.setViewVisibility(slot, View.INVISIBLE)
                    continue
                }
                val effect = effects.getJSONObject(index)
                views.setViewVisibility(slot, View.VISIBLE)
                views.setTextViewText(slot, effect.optString("name"))
                tint(views, slot, effect)
                views.setOnClickPendingIntent(slot, open(context, index, effect.optString("link")))
            }
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                views.setOnClickPendingIntent(
                    R.id.widget_title,
                    PendingIntent.getActivity(
                        context, 100, it,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            }
            return views
        }

        /** The tile takes the effect's main colour, keeping its rounded shape. */
        private fun tint(views: RemoteViews, slot: Int, effect: JSONObject) {
            val colors = effect.optJSONArray("colors") ?: return
            if (colors.length() > 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val color = colors.optLong(0).toInt()
                views.setColorStateList(
                    slot, "setBackgroundTintList", ColorStateList.valueOf(color),
                )
            }
        }

        private fun open(context: Context, index: Int, link: String): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(
                context, index, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}

/** The widget's content, as last sent by the app over `com.lumifx/widgets`. */
object WidgetData {
    private const val PREFS = "lumifx_widget"
    private const val KEY = "content"

    fun save(context: Context, content: JSONObject) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, content.toString()).apply()
    }

    fun read(context: Context): JSONObject? = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)?.let { JSONObject(it) }
    } catch (e: Exception) {
        null
    }
}
