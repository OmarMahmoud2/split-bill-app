package net.omarmali.splitapp.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import net.omarmali.splitapp.R

/**
 * Small "You're owed / You owe" widget.
 *
 * Value changes cross-fade: the amount lives in a ViewFlipper with fade
 * in/out animations, and a new amount is written into the hidden child
 * before flipping to it. Launchers that re-inflate instead of reapplying
 * RemoteViews show the new value without the fade.
 */
class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayload.from(widgetData)
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_balance)
            WidgetViews.applyDirection(views, R.id.widget_root, payload)
            val balance = payload?.balance
            if (payload == null || !payload.signedIn || balance == null) {
                views.setViewVisibility(R.id.balance_content, View.GONE)
                views.setViewVisibility(R.id.balance_message, View.VISIBLE)
                views.setTextViewText(
                    R.id.balance_message,
                    payload?.string("signIn", "")?.ifEmpty { null }
                        ?: context.getString(R.string.widget_open_app),
                )
            } else {
                views.setViewVisibility(R.id.balance_content, View.VISIBLE)
                views.setViewVisibility(R.id.balance_message, View.GONE)
                views.setTextViewText(R.id.balance_label, balance.label)
                bindAmount(context, views, state, id, balance)
                val caption = payload.string("updatedAt", "")
                views.setTextViewText(
                    R.id.balance_caption,
                    if (balance.count > 0) "${balance.count} · $caption" else caption,
                )
                views.setViewVisibility(
                    R.id.balance_people_icon,
                    if (balance.count > 0) View.VISIBLE else View.GONE,
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetViews.launch(context, payload?.homeUrl ?: WidgetPayload.HOME_URL),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bindAmount(
        context: Context,
        views: RemoteViews,
        state: SharedPreferences,
        widgetId: Int,
        balance: WidgetPayload.Balance,
    ) {
        val shownKey = "balance_amount_$widgetId"
        val childKey = "balance_child_$widgetId"
        var child = state.getInt(childKey, 0)
        if (state.getString(shownKey, null) != balance.amount) {
            child = 1 - child
            state.edit().putString(shownKey, balance.amount).putInt(childKey, child).apply()
        }
        val color = WidgetViews.amountColor(balance.sign)
        for (viewId in AMOUNT_VIEWS) {
            views.setTextViewText(viewId, balance.amount)
            WidgetViews.setTextColorRes(context, views, viewId, color)
        }
        views.setDisplayedChild(R.id.balance_amount_flipper, child)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val editor = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach {
            editor.remove("balance_amount_$it").remove("balance_child_$it")
        }
        editor.apply()
    }

    private companion object {
        const val STATE_PREFS = "split_bill_widget_state"
        val AMOUNT_VIEWS = intArrayOf(R.id.balance_amount_a, R.id.balance_amount_b)
    }
}
