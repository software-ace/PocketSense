package ace.software.pocketsense

import android.content.Context
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

    // Keeps balances out of the recent-apps preview, screenshots and screen
    // recordings, as banking apps do. On from the start; Settings → Security
    // can turn it off (pocketsense/window below).
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
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

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
