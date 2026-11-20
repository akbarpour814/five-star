package ir.fivestar.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Keeps replies from registered device numbers until Flutter drains them,
 * so messages that arrive while the app is closed are not lost.
 * SMS from any other sender is never stored.
 */
object SmsStore {
    private const val PREFS = "fivestar_sms"
    private const val KEY_WATCHED = "watched"
    private const val KEY_PENDING = "pending"
    private const val MAX_PENDING = 100

    @Volatile
    var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun matchKey(number: String): String {
        val digits = number.filter { it.isDigit() }
        return if (digits.length > 10) digits.takeLast(10) else digits
    }

    @Synchronized
    fun setWatchedNumbers(context: Context, numbers: List<String>) {
        prefs(context).edit().putStringSet(KEY_WATCHED, numbers.map(::matchKey).toSet()).apply()
    }

    fun isWatched(context: Context, sender: String): Boolean =
        prefs(context).getStringSet(KEY_WATCHED, emptySet())?.contains(matchKey(sender)) == true

    @Synchronized
    fun add(context: Context, sender: String, body: String, timestamp: Long) {
        val pending = JSONArray(prefs(context).getString(KEY_PENDING, "[]"))
        pending.put(JSONObject().put("sender", sender).put("body", body).put("timestamp", timestamp))
        while (pending.length() > MAX_PENDING) pending.remove(0)
        prefs(context).edit().putString(KEY_PENDING, pending.toString()).apply()
        mainHandler.post { sink?.success("new") }
    }

    @Synchronized
    fun drain(context: Context): List<Map<String, Any>> {
        val pending = JSONArray(prefs(context).getString(KEY_PENDING, "[]"))
        prefs(context).edit().putString(KEY_PENDING, "[]").apply()
        return (0 until pending.length()).map { i ->
            val item = pending.getJSONObject(i)
            mapOf(
                "sender" to item.getString("sender"),
                "body" to item.getString("body"),
                "timestamp" to item.getLong("timestamp"),
            )
        }
    }

    @Synchronized
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
