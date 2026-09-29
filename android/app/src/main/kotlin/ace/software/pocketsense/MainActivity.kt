package ace.software.pocketsense

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt
// (local_auth, androidx.biometric) is a fragment and needs one to attach to.
class MainActivity : FlutterFragmentActivity()
