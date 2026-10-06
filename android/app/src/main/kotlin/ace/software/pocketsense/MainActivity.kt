package ace.software.pocketsense

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt
// (local_auth, androidx.biometric) is a fragment and needs one to attach to.
class MainActivity : FlutterFragmentActivity() {
    // Android drops incoming multicast to save battery unless an app holds
    // this lock; sync's device discovery needs it while sync is running.
    private var multicastLock: WifiManager.MulticastLock? = null

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
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
