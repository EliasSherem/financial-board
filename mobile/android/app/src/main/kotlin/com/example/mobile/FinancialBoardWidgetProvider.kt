package com.example.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinancialBoardWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_quick_transaction)

      val amount =
          widgetData
              .getString(
                  KEY_DISPLAY_VALUE, context.getString(R.string.widget_default_amount))
              ?: context.getString(R.string.widget_default_amount)
      val monthLabel =
          widgetData
              .getString(
                  KEY_MONTH_LABEL, context.getString(R.string.widget_default_month))
              ?: context.getString(R.string.widget_default_month)

      views.setTextViewText(R.id.widget_amount, amount)
      views.setTextViewText(R.id.widget_month_label, monthLabel)

      val launchIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("financialboard://widget/$ACTION_CREATE_TRANSACTION"),
          )
      val recurringIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("financialboard://widget/$ACTION_CREATE_RECURRING"),
          )
      views.setOnClickPendingIntent(R.id.widget_action_container, launchIntent)
      views.setOnClickPendingIntent(R.id.widget_recurring_container, recurringIntent)
      views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  companion object {
    private const val ACTION_CREATE_TRANSACTION = "create-transaction"
    private const val ACTION_CREATE_RECURRING = "create-recurring-payment"
    private const val KEY_DISPLAY_VALUE = "kpi_spent_display"
    private const val KEY_MONTH_LABEL = "kpi_spent_month_label"
  }
}
