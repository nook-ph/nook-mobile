package app.nookph

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * "Your saved cafes": the Want to try cafes that are open now.
 *
 * Draws only. The app works out what to show for the coming week
 * (`lib/features/home_widget/domain/saved_cafes_widget_data.dart`) and writes
 * it under [DATA_KEY] as a list of frames, each with the time it starts. This
 * shows the last frame that has started; the app schedules an update for each
 * frame, and `updatePeriodMillis` (2 hours) is the safety net. Past the
 * payload's `until` it says to open Nook rather than show hours that may no
 * longer hold. It never asks for a position: distances come from the app.
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
    }

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
        val content = Content.read(data.getString(DATA_KEY, null), System.currentTimeMillis())
        val small = fill(context, R.layout.saved_cafes_widget_small, 1, content)
        val medium = fill(context, R.layout.saved_cafes_widget_medium, 3, content)
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

    private fun fill(context: Context, layout: Int, slots: Int, content: Content): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        views.setOnClickPendingIntent(R.id.header, launch(context, "nook://saved?via=widget"))

        if (layout == R.layout.saved_cafes_widget_medium) {
            val count = when {
                content.rows.isEmpty() -> ""
                content.openCount == 0 -> "None open now"
                else -> "${content.openCount} open now"
            }
            views.setTextViewText(R.id.header_count, count)
        }

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

        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2)
        private val NAME_IDS = intArrayOf(R.id.row_0_name, R.id.row_1_name, R.id.row_2_name)
        private val LINE_IDS = intArrayOf(R.id.row_0_line, R.id.row_1_line, R.id.row_2_line)
        private val DOT_IDS = intArrayOf(R.id.row_0_dot, R.id.row_1_dot, R.id.row_2_dot)
    }
}
