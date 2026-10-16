package app.nookph

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Date

/**
 * "Your saved cafes": the Want to try cafes that are open now.
 *
 * Draws only. The app works out what to show for the coming week
 * (`lib/features/home_widget/domain/saved_cafes_widget_data.dart`) and writes
 * it under [DATA_KEY] as a list of frames, each with the time it starts. This
 * shows the last frame that has started. Each time it draws, it arms one
 * alarm for the next frame's start (or `until`) with a 10-minute window
 * ([armNextTurnover]: `AlarmManager.setWindow`, which needs no exact-alarm
 * permission), so an opening or closing shows within about 10 minutes with or
 * without the app. `updatePeriodMillis` (30 minutes, the platform minimum) is
 * the safety net, and also covers a reboot, after which the system redraws
 * the widget anyway. Past the payload's `until` it says to open Nook rather
 * than show hours that may no longer hold. It never asks for a position:
 * distances come from the app.
 *
 * Taps open `nook://` links the app routes (see `lib/features/home_widget/presentation/widget_links.dart`).
 */
class SavedCafesWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id, widgetData))
        }
        armNextTurnover(context, widgetData)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TURNOVER) {
            super.onReceive(context, intent)
            return
        }
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, SavedCafesWidgetProvider::class.java))
        if (ids.isEmpty()) return
        onUpdate(context, manager, ids, es.antonborri.home_widget.HomeWidgetPlugin.getData(context))
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        alarmManager(context)?.cancel(turnoverIntent(context))
    }

    /**
     * One alarm, always for the next turnover; re-armed on every draw, so a
     * new payload from the app replaces it. Inexact by design: a window of
     * [TURNOVER_WINDOW_MS] starting at the turnover. Android 12+ will not
     * shorten a window below 10 minutes, and Doze can still hold it until the
     * next maintenance window while the phone lies idle (the widget is not
     * being looked at then, and the next draw catches up).
     */
    private fun armNextTurnover(context: Context, data: SharedPreferences) {
        val alarms = alarmManager(context) ?: return
        val intent = turnoverIntent(context)
        val next = Content.nextTurnover(data.getString(DATA_KEY, null), System.currentTimeMillis())
        if (next == null) {
            alarms.cancel(intent)
            return
        }
        alarms.setWindow(AlarmManager.RTC_WAKEUP, next, TURNOVER_WINDOW_MS, intent)
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

    private fun turnoverIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        TURNOVER_REQUEST_CODE,
        Intent(context, SavedCafesWidgetProvider::class.java).setAction(ACTION_TURNOVER),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetManager, appWidgetId, data))
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ): RemoteViews {
        val now = System.currentTimeMillis()
        val content = Content.read(data.getString(DATA_KEY, null), now)
        // At large font scales three rows of two lines do not fit a 4x2:
        // two rows, so every status line shows in full (names ellipsize).
        val largeText = context.resources.configuration.fontScale >= LARGE_TEXT_SCALE
        val small = fill(context, R.layout.saved_cafes_widget_small, 1, content, now)
        val medium = if (largeText) {
            fill(context, R.layout.saved_cafes_widget_medium_large, 2, content, now)
        } else {
            fill(context, R.layout.saved_cafes_widget_medium, 3, content, now)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launcher picks the largest layout that fits the current size.
            return RemoteViews(
                mapOf(
                    SizeF(100f, 100f) to small,
                    SizeF(220f, 100f) to medium,
                ),
            )
        }
        val minWidth = manager.getAppWidgetOptions(widgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        return if (minWidth < 220) small else medium
    }

    private fun fill(context: Context, layout: Int, slots: Int, content: Content, now: Long): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        views.setOnClickPendingIntent(R.id.header, launch(context, "nook://saved?via=widget"))

        // "2 open · 3:10 PM": a count with the time it was drawn, so it
        // reads as a claim about that moment, not a standing fact.
        val count = if (content.rows.isEmpty()) {
            ""
        } else {
            val time = DateFormat.getTimeFormat(context).format(Date(now))
            val open = if (content.openCount == 0) "None open" else "${content.openCount} open"
            "$open · $time"
        }
        views.setTextViewText(R.id.header_count, count)
        views.setViewVisibility(R.id.header_count, if (count.isEmpty()) View.GONE else View.VISIBLE)

        if (content.rows.isEmpty()) {
            views.setViewVisibility(R.id.rows, View.GONE)
            views.setViewVisibility(R.id.empty, View.VISIBLE)
            if (content.stale) {
                views.setTextViewText(R.id.empty_text, context.getString(R.string.saved_cafes_widget_stale))
                views.setViewVisibility(R.id.empty_action, View.GONE)
                views.setOnClickPendingIntent(R.id.empty, launch(context, "nook://saved?via=widget&tap=stale"))
            } else {
                views.setTextViewText(R.id.empty_text, context.getString(R.string.saved_cafes_widget_empty))
                views.setViewVisibility(R.id.empty_action, View.VISIBLE)
                views.setOnClickPendingIntent(R.id.empty, launch(context, "nook://home?via=widget"))
            }
            return views
        }

        views.setViewVisibility(R.id.empty, View.GONE)
        views.setViewVisibility(R.id.rows, View.VISIBLE)
        for (i in 0 until slots) {
            val rowId = ROW_IDS[i]
            val row = content.rows.getOrNull(i)
            if (row == null) {
                // Invisible, not gone: the rows above keep their places.
                views.setViewVisibility(rowId, View.INVISIBLE)
                continue
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(NAME_IDS[i], row.name)
            views.setTextViewText(LINE_IDS[i], row.line)
            views.setInt(DOT_IDS[i], "setColorFilter", ContextCompat.getColor(context, toneColor(row.tone)))
            views.setContentDescription(rowId, "${row.name}, ${row.line}")
            views.setOnClickPendingIntent(
                rowId,
                launch(context, "nook://cafe/${Uri.encode(row.id)}?via=widget"),
            )
        }
        return views
    }

    private fun toneColor(tone: String): Int = when (tone) {
        "open" -> R.color.widget_open
        "closingSoon" -> R.color.widget_soon
        else -> R.color.widget_closed
    }

    private fun launch(context: Context, link: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

    private class Row(val id: String, val name: String, val line: String, val tone: String)

    private class Content(val rows: List<Row>, val openCount: Int, val stale: Boolean) {
        companion object {
            private val EMPTY = Content(emptyList(), 0, stale = false)

            /** The next frame start after [now], else `until`, else null. */
            fun nextTurnover(raw: String?, now: Long): Long? {
                if (raw.isNullOrEmpty()) return null
                return try {
                    val json = JSONObject(raw)
                    val frames = json.optJSONArray("frames")
                    if (frames != null) {
                        for (i in 0 until frames.length()) {
                            val t = frames.getJSONObject(i).optLong("t")
                            if (t > now) return t
                        }
                    }
                    json.optLong("until", 0L).takeIf { it > now }
                } catch (e: Exception) {
                    null
                }
            }

            fun read(raw: String?, now: Long): Content {
                if (raw.isNullOrEmpty()) return EMPTY
                return try {
                    val json = JSONObject(raw)
                    val names = json.optJSONObject("names") ?: JSONObject()
                    val frames = json.optJSONArray("frames")
                    if (names.length() == 0 || frames == null || frames.length() == 0) return EMPTY
                    if (now >= json.optLong("until", 0L)) return Content(emptyList(), 0, stale = true)

                    // The last frame that has started; the first one if the
                    // clock is behind the payload.
                    var frame = frames.getJSONObject(0)
                    for (i in 0 until frames.length()) {
                        val candidate = frames.getJSONObject(i)
                        if (candidate.optLong("t") <= now) frame = candidate else break
                    }
                    val rows = mutableListOf<Row>()
                    val array = frame.optJSONArray("rows")
                    if (array != null) {
                        for (i in 0 until array.length()) {
                            val r = array.getJSONArray(i)
                            val id = r.optString(0)
                            val name = names.optString(id)
                            if (id.isEmpty() || name.isEmpty()) continue
                            rows.add(Row(id, name, r.optString(1), r.optString(2)))
                        }
                    }
                    Content(rows, frame.optInt("o"), stale = false)
                } catch (e: Exception) {
                    EMPTY
                }
            }
        }
    }

    companion object {
        /** Written by the app; see `SavedCafesWidgetData.toJson`. */
        const val DATA_KEY = "saved_cafes_v1"

        private const val ACTION_TURNOVER = "app.nookph.widget.SAVED_CAFES_TURNOVER"
        private const val TURNOVER_REQUEST_CODE = 4101
        private const val TURNOVER_WINDOW_MS = 10 * 60 * 1000L

        /** Above Android's "Large" font size (1.15); "Largest" is 1.3, and 14+ goes to 2.0. */
        private const val LARGE_TEXT_SCALE = 1.2f

        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2)
        private val NAME_IDS = intArrayOf(R.id.row_0_name, R.id.row_1_name, R.id.row_2_name)
        private val LINE_IDS = intArrayOf(R.id.row_0_line, R.id.row_1_line, R.id.row_2_line)
        private val DOT_IDS = intArrayOf(R.id.row_0_dot, R.id.row_1_dot, R.id.row_2_dot)
    }
}
