package com.monetizer.app

import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Store builds block screenshots and the recent-apps preview of financial
        // data. Debug builds allow them, so the store screenshots can be taken.
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!debuggable) {
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
