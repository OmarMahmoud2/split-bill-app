package net.omarmali.splitapp.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import net.omarmali.splitapp.R

/** Small teal tile that opens the receipt scanner. */
class ScanWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayload.from(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_scan)
            WidgetViews.applyDirection(views, R.id.widget_root, payload)
            views.setTextViewText(
                R.id.scan_label,
                payload?.string("scan", "")?.ifEmpty { null }
                    ?: context.getString(R.string.widget_scan_receipt_sample),
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetViews.launch(context, payload?.scanUrl ?: WidgetPayload.SCAN_URL),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
