package app.nookph

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
