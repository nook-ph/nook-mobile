package app.nookph

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationManagerCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Reopened from Recents, or rebuilt after the process died: the
        // activity gets back the intent that first launched it. A widget tap
        // in it was already handled, so drop its link before Flutter and the
        // widget plugin read it again (it would reopen the cafe and log
        // another widget_tapped).
        val launchedFromHistory =
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if ((savedInstanceState != null || launchedFromHistory) &&
            intent.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        ) {
            intent = Intent(intent).setAction(Intent.ACTION_MAIN).setData(null)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // A widget tap that recreates the activity (process gone, task kept)
        // arrives here before Dart is listening. Keeping it as the activity's
        // intent lets the app read it on start
        // (HomeWidget.initiallyLaunchedFromHomeWidget).
        setIntent(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
