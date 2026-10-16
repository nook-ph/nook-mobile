package app.nookph

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Reopened from Recents, or rebuilt after the process died: the
        // activity gets back the intent that first launched it. A widget or
        // visit-reminder tap in it was already handled, so drop it before
        // Flutter and the plugins read it again (the widget link would
        // reopen the cafe and log another widget_tapped; the notification
        // would count as a launch tap again and re-run "I went").
        // flutter_local_notifications only checks the history flag, not a
        // restore.
        val launchedFromHistory =
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if ((savedInstanceState != null || launchedFromHistory) &&
            intent.action in HANDLED_LAUNCH_ACTIONS
        ) {
            intent = Intent(intent).setAction(Intent.ACTION_MAIN).setData(null)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // A widget tap that recreates the activity (process gone, task kept)
        // arrives here before Dart is listening. Keeping it as the activity's
        // intent lets the app read it on start
        // (HomeWidget.initiallyLaunchedFromHomeWidget). Only widget taps:
        // an intent set here survives an in-process relaunch (a config
        // change), so an OAuth callback, App Link or notification tap kept
        // this way would be read again as the launch link by the new engine.
        if (intent.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) {
            setIntent(intent)
        }
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Settings > Visit reminders > Open settings, when only the "Visits and
        // ratings" channel is muted: its own page, not the app's list.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.nookph/notification_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openChannel" || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.success(false)
                return@setMethodCallHandler
            }
            val channelId = call.argument<String>("channelId")
            try {
                startActivity(
                    Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    },
                )
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
        // Whether this app may post notifications at all, and the API level
        // (off on SDK < 33 is a choice; on 33+ it is also "never asked"), for
        // the home-screen widget promo aimed at people who keep them off.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.nookph/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "areEnabled" -> result.success(
                        NotificationManagerCompat.from(this).areNotificationsEnabled(),
                    )
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        /** Launch intents the app acts on once: a widget tap, and a visit
         *  reminder tap or its "I went" (flutter_local_notifications). */
        val HANDLED_LAUNCH_ACTIONS = setOf(
            HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION,
            "SELECT_NOTIFICATION",
            "SELECT_FOREGROUND_NOTIFICATION",
        )
    }
}
