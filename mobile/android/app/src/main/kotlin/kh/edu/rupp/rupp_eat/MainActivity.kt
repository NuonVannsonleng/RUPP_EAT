package kh.edu.rupp.rupp_eat

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets Dart know whether a Google Maps key was configured (android/local.properties).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kh.edu.rupp.rupp_eat/config")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasMapsKey") {
                    val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val key = info.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
                    result.success(key.startsWith("AIza"))
                } else {
                    result.notImplemented()
                }
            }
    }
}
