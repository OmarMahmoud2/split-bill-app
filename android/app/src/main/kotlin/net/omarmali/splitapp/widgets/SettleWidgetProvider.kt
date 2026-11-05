package net.omarmali.splitapp.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import net.omarmali.splitapp.R

/** Medium "Settle with" widget: top 3 people, each row deep-links. */
class SettleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayload.from(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_settle)
            WidgetViews.applyDirection(views, R.id.widget_root, payload)
            val homeUrl = payload?.homeUrl ?: WidgetPayload.HOME_URL
            views.setOnClickPendingIntent(R.id.widget_root, WidgetViews.launch(context, homeUrl))

            if (payload == null || !payload.signedIn) {
                views.setViewVisibility(R.id.settle_content, View.GONE)
                views.setViewVisibility(R.id.settle_message, View.VISIBLE)
                views.setTextViewText(
                    R.id.settle_message,
                    payload?.string("signIn", "")?.ifEmpty { null }
                        ?: context.getString(R.string.widget_open_app),
                )
            } else {
                views.setViewVisibility(R.id.settle_content, View.VISIBLE)
                views.setViewVisibility(R.id.settle_message, View.GONE)
                views.setTextViewText(
                    R.id.settle_title,
                    payload.string("settleWith", context.getString(R.string.widget_settle_name)),
                )
                ROWS.forEachIndexed { index, row ->
                    val person = payload.people.getOrNull(index)
                    if (person == null) {
                        views.setViewVisibility(row.container, View.GONE)
                    } else {
                        views.setViewVisibility(row.container, View.VISIBLE)
                        views.setTextViewText(row.name, person.name)
                        views.setTextViewText(row.amount, person.amount)
                        WidgetViews.setTextColorRes(
                            context, views, row.amount, WidgetViews.amountColor(person.sign),
                        )
                        views.setOnClickPendingIntent(
                            row.container, WidgetViews.launch(context, person.url),
                        )
                    }
                }
                views.setViewVisibility(
                    R.id.settle_empty,
                    if (payload.people.isEmpty()) View.VISIBLE else View.GONE,
                )
                views.setTextViewText(R.id.settle_empty, payload.string("noBalances", ""))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private data class Row(val container: Int, val name: Int, val amount: Int)

    private companion object {
        val ROWS = listOf(
            Row(R.id.settle_row_1, R.id.settle_name_1, R.id.settle_amount_1),
            Row(R.id.settle_row_2, R.id.settle_name_2, R.id.settle_amount_2),
            Row(R.id.settle_row_3, R.id.settle_name_3, R.id.settle_amount_3),
        )
    }
}
