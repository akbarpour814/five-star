package ir.fivestar.app

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {

    private class SimNotFoundException : Exception()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "fivestar/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "send" -> {
                    val number = call.argument<String>("number")
                    val body = call.argument<String>("body")
                    val slot = call.argument<Int>("slot")
                    if (number.isNullOrBlank() || body.isNullOrEmpty()) {
                        result.error("ARGS", "number and body are required", null)
                    } else {
                        try {
                            sendSms(number, body, slot)
                            result.success(true)
                        } catch (e: SimNotFoundException) {
                            result.error("SIM_NOT_FOUND", "No active SIM in slot $slot", null)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", e.message, null)
                        }
                    }
                }
                "simCards" -> {
                    try {
                        result.success(simCards())
                    } catch (e: SecurityException) {
                        result.error("PERMISSION", e.message, null)
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

    private val subscriptionManager: SubscriptionManager
        get() = getSystemService(SubscriptionManager::class.java)

    private fun hasPermission(permission: String) =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    private fun simCards(): List<Map<String, Any?>> {
        val infos: List<SubscriptionInfo> = subscriptionManager.activeSubscriptionInfoList ?: emptyList()
        return infos.map { info ->
            mapOf(
                "slot" to info.simSlotIndex,
                "carrier" to (info.carrierName?.toString() ?: info.displayName?.toString()),
                "number" to phoneNumber(info),
            )
        }
    }

    // Many operators do not store the number on the SIM, so every known source is tried and it may still be empty.
    @SuppressLint("MissingPermission", "HardwareIds")
    private fun phoneNumber(info: SubscriptionInfo): String? {
        val candidates = mutableListOf<() -> String?>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (hasPermission(Manifest.permission.READ_PHONE_NUMBERS)) {
                val id = info.subscriptionId
                candidates += { subscriptionManager.getPhoneNumber(id) }
                candidates += { subscriptionManager.getPhoneNumber(id, SubscriptionManager.PHONE_NUMBER_SOURCE_UICC) }
                candidates += { subscriptionManager.getPhoneNumber(id, SubscriptionManager.PHONE_NUMBER_SOURCE_CARRIER) }
                candidates += { subscriptionManager.getPhoneNumber(id, SubscriptionManager.PHONE_NUMBER_SOURCE_IMS) }
            }
        } else {
            @Suppress("DEPRECATION")
            candidates += { info.number }
        }
        candidates += {
            @Suppress("DEPRECATION")
            getSystemService(TelephonyManager::class.java).createForSubscriptionId(info.subscriptionId).line1Number
        }
        for (candidate in candidates) {
            val value = try {
                candidate()
            } catch (e: Exception) {
                null
            }
            if (!value.isNullOrBlank()) return value
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun smsManagerFor(slot: Int?): SmsManager {
        val default: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        if (slot == null) return default
        val info = subscriptionManager.getActiveSubscriptionInfoForSimSlotIndex(slot) ?: throw SimNotFoundException()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            default.createForSubscriptionId(info.subscriptionId)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getSmsManagerForSubscriptionId(info.subscriptionId)
        }
    }

    private fun sendSms(number: String, body: String, slot: Int?) {
        val manager = smsManagerFor(slot)
        val parts = manager.divideMessage(body)
        if (parts.size > 1) {
            manager.sendMultipartTextMessage(number, null, parts, null, null)
        } else {
            manager.sendTextMessage(number, null, body, null, null)
        }
    }
}
