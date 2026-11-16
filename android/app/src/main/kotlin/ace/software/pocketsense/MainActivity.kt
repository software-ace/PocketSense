package ace.software.pocketsense

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt
// (local_auth, androidx.biometric) is a fragment and needs one to attach to.
class MainActivity : FlutterFragmentActivity() {
    // Android drops incoming multicast to save battery unless an app holds
    // this lock; sync's device discovery needs it while sync is running.
    private var multicastLock: WifiManager.MulticastLock? = null

    // The home-screen widget and app-icon shortcuts open the app with one of
    // these actions; Dart takes the one from launch, and is sent later ones.
    private var pendingQuickAdd: String? = null
    private var quickAddChannel: MethodChannel? = null

    // An Account widget tapped before it had an account (BalanceWidgets):
    // Dart takes the one from launch, and is sent later ones.
    private var pendingWidgetChoice: Int? = null

    // Keeps balances out of the recent-apps preview, screenshots and screen
    // recordings, as banking apps do. On from the start; Settings → Security
    // can turn it off (pocketsense/window below).
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        // Not again when Android recreates the activity with the same intent.
        if (savedInstanceState == null) {
            pendingQuickAdd = quickAdd(intent)
            pendingWidgetChoice = widgetChoice(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        widgetChoice(intent)?.let { id -> BalanceWidgets.channel?.invokeMethod("choose", id) ?: run { pendingWidgetChoice = id } }
        val action = quickAdd(intent) ?: return
        quickAddChannel?.invokeMethod("open", action) ?: run { pendingQuickAdd = action }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketsense/multicast").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    val lock = multicastLock ?: wifi.createMulticastLock("pocketsense-sync").also {
                        it.setReferenceCounted(false)
                        multicastLock = it
                    }
                    lock.acquire()
                    result.success(null)
                }
                "release" -> {
                    multicastLock?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        quickAddChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketsense/quickadd").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pendingQuickAdd)
                    pendingQuickAdd = null
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketsense/window").setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                if (call.arguments as Boolean) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        backgroundChannel(flutterEngine)
        widgetsChannel(flutterEngine)
    }

    private fun widgetsChannel(flutterEngine: FlutterEngine) {
        BalanceWidgets.channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketsense/widgets").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "ids" -> result.success(BalanceWidgets.ids(applicationContext))
                    "show" -> {
                        BalanceWidgets.show(applicationContext, call.arguments as Map<*, *>)
                        result.success(null)
                    }
                    "clear" -> {
                        BalanceWidgets.clear(applicationContext)
                        result.success(null)
                    }
                    "take" -> {
                        result.success(pendingWidgetChoice)
                        pendingWidgetChoice = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // Reminders: some makers stop apps' alarms unless allowed in their own
    // settings, which have no API; Dart names them and opens App info.
    private fun backgroundChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketsense/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "manufacturer" -> result.success(Build.MANUFACTURER)
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        quickAddChannel = null
        BalanceWidgets.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }

    companion object {
        const val ACTION_ADD_EXPENSE = "ace.software.pocketsense.ADD_EXPENSE"
        const val ACTION_ADD_INCOME = "ace.software.pocketsense.ADD_INCOME"
        const val ACTION_ADD_VOICE = "ace.software.pocketsense.ADD_VOICE"

        // Reopening from recent apps replays the intent that started the task:
        // a widget tap from then must not open the form (or the mic) again.
        fun quickAdd(intent: Intent?): String? = if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) null else when (intent.action) {
            ACTION_ADD_EXPENSE -> "expense"
            ACTION_ADD_INCOME -> "income"
            ACTION_ADD_VOICE -> "voice"
            else -> null
        }

        // As [quickAdd]: not again when reopened from recent apps.
        fun widgetChoice(intent: Intent?): Int? =
            if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0 || intent.action != BalanceWidgets.ACTION_CHOOSE_ACCOUNT) null
            else intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID).takeIf { it != AppWidgetManager.INVALID_APPWIDGET_ID }
    }
}
