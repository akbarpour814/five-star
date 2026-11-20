package ir.fivestar.app

import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "fivestar/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "send" -> {
                    val number = call.argument<String>("number")
                    val body = call.argument<String>("body")
                    if (number.isNullOrBlank() || body.isNullOrEmpty()) {
                        result.error("ARGS", "number and body are required", null)
                    } else {
                        try {
                            sendSms(number, body)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", e.message, null)
                        }
                    }
                }
                "watchNumbers" -> {
                    SmsStore.setWatchedNumbers(this, call.argument<List<String>>("numbers") ?: emptyList())
                    result.success(null)
                }
                "drainPending" -> result.success(SmsStore.drain(this))
                "clear" -> {
                    SmsStore.clear(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "fivestar/sms_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                SmsStore.sink = events
            }

            override fun onCancel(arguments: Any?) {
                SmsStore.sink = null
            }
        })
    }

    private fun sendSms(number: String, body: String) {
        val manager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = manager.divideMessage(body)
        if (parts.size > 1) {
            manager.sendMultipartTextMessage(number, null, parts, null, null)
        } else {
            manager.sendTextMessage(number, null, body, null, null)
        }
    }
}
