package ir.fivestar.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return

        // Long replies arrive as several parts in one intent; join them per sender.
        messages
            .filter { it.originatingAddress != null }
            .groupBy { it.originatingAddress!! }
            .forEach { (sender, parts) ->
                if (!SmsStore.isWatched(context, sender)) return@forEach
                val body = parts.joinToString(separator = "") { it.messageBody ?: "" }
                val timestamp = parts.minOf { it.timestampMillis }
                SmsStore.add(context, sender, body, timestamp)
            }
    }
}
