package ace.software.pocketsense

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Bundle
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

    // Keeps balances out of the recent-apps preview, screenshots and screen
    // recordings, as banking apps do. On from the start; Settings → Security
    // can turn it off (pocketsense/window below).
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        // Not again when Android recreates the activity with the same intent.
        if (savedInstanceState == null) pendingQuickAdd = quickAdd(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        quickAddChannel = null
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
    }
}
