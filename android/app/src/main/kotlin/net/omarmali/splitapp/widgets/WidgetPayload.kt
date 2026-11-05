package net.omarmali.splitapp.widgets

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.ColorRes
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import net.omarmali.splitapp.MainActivity
import net.omarmali.splitapp.R
import org.json.JSONObject

/**
 * The JSON payload written by Flutter (lib/services/home_widget_data.dart,
 * key `sb_widget_payload`). Every label and amount is already localized and
 * formatted in Dart; the providers only bind it to RemoteViews.
 */
data class WidgetPayload(
    val signedIn: Boolean,
    val rtl: Boolean,
    val strings: JSONObject,
    val scanUrl: String,
    val homeUrl: String,
    val balance: Balance?,
    val people: List<Person>,
) {
    data class Balance(
        val label: String,
        val amount: String,
        val sign: Int,
        val count: Int,
    )

    data class Person(val name: String, val amount: String, val sign: Int, val url: String)

    fun string(key: String, fallback: String): String =
        strings.optString(key).takeIf { it.isNotEmpty() } ?: fallback

    companion object {
        const val KEY = "sb_widget_payload"
        private const val SUPPORTED_VERSION = 1
        const val HOME_URL = "splitbill://widget/home?homeWidget"
        const val SCAN_URL = "splitbill://widget/scan?homeWidget"

        fun from(prefs: SharedPreferences): WidgetPayload? = parse(prefs.getString(KEY, null))

        fun parse(json: String?): WidgetPayload? {
            if (json.isNullOrEmpty()) return null
            return try {
                val root = JSONObject(json)
                if (root.optInt("v") > SUPPORTED_VERSION) return null
                val balance = root.optJSONObject("balance")?.let {
                    Balance(
                        label = it.optString("label"),
                        amount = it.optString("amount"),
                        sign = it.optInt("sign"),
                        count = it.optInt("count"),
                    )
                }
                val peopleJson = root.optJSONArray("people")
                val people = (0 until (peopleJson?.length() ?: 0)).mapNotNull { index ->
                    peopleJson?.optJSONObject(index)?.let {
                        Person(
                            name = it.optString("name"),
                            amount = it.optString("amount"),
                            sign = it.optInt("sign"),
                            url = it.optString("url").ifEmpty { HOME_URL },
                        )
                    }
                }
                WidgetPayload(
                    signedIn = root.optString("state") == "ready" && balance != null,
                    rtl = root.optString("dir") == "rtl",
                    strings = root.optJSONObject("strings") ?: JSONObject(),
                    scanUrl = root.optString("scanUrl").ifEmpty { SCAN_URL },
                    homeUrl = root.optString("homeUrl").ifEmpty { HOME_URL },
                    balance = balance,
                    people = people,
                )
            } catch (_: Exception) {
                null
            }
        }
    }
}

internal object WidgetViews {
    /** Launches MainActivity with a widget URI; routed by home_widget in Dart. */
    fun launch(context: Context, url: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(url))

    /**
     * The app has its own language setting, so the widget follows the
     * payload's direction rather than the device's.
     */
    fun applyDirection(views: RemoteViews, rootId: Int, payload: WidgetPayload?) {
        if (payload == null) return
        views.setInt(
            rootId,
            "setLayoutDirection",
            if (payload.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
        )
    }

    @ColorRes
    fun amountColor(sign: Int): Int = when {
        sign > 0 -> R.color.widget_positive
        sign < 0 -> R.color.widget_negative
        else -> R.color.widget_ink
    }

    /**
     * Android 12+ resolves the color resource in the launcher, so it follows
     * light/dark changes without an app update; older versions bake it in.
     */
    fun setTextColorRes(context: Context, views: RemoteViews, viewId: Int, @ColorRes color: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColor(viewId, "setTextColor", color)
        } else {
            views.setTextColor(viewId, context.getColor(color))
        }
    }
}
