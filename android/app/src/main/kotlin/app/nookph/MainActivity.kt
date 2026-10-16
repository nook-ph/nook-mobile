package app.nookph

import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
        // Whether this app may post notifications at all, for the
        // home-screen widget promo aimed at people who keep them off.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.nookph/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "areEnabled" -> result.success(
                        NotificationManagerCompat.from(this).areNotificationsEnabled(),
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
